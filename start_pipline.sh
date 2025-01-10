#!/bin/bash

num_instances=1
num_proc=48
domain_source="db"
build="no"
verbos="no"
container_path=()
steps="all"
cache="yes"
directory=""
sel="yes"
mongo="yes"

handle_error() {
    echo "Error: $1"
    exit 1
}

check_env_vars() {
    local missing_vars=0

    # List of required environment variables
    local required_vars=(
        "VOLUME_DIR"
        "VOLUME_MONGO"
        "SCAMAGNIFIER_DATE"
        "SCAMAGNIFIER_SELENIUM_ADDRESS"
        "SCAMAGNIFIER_SELENIUM_PORT"
        "SCAMAGNIFIER_MONGO_PORT"
        "SCAMAGNIFIER_FE_CPU"
        "SCAMAGNIFIER_DC_CPU"
        "SCAMAGNIFIER_SC_CPU"
        "SCAMAGNIFIER_AC_CPU"
    )

    for var_name in "${required_vars[@]}"; do
        echo "check : ${var_name}"
        if [ -z "${!var_name}" ]; then
            handle_error "Environment variable $var_name is not set or empty."
            missing_vars=1
        fi
    done

    return $missing_vars
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --instance <num>   Number of instances (default: 1)"
    echo "  --process <num>    Number of processes (default: 48)"
    echo "  --domainsource <source>   Domain source (db/file) (default: db)"
    echo "  --domainfile <file>   Domain file path"
    echo "  --build <yes/no>    Build components (default: no)"
    echo "  --cache <yes/no>    Use cache during build (default: yes)"
    echo "  --verbos <yes/no>   Verbose mode (default: no)"
    echo "  --directory <dir>   Output directory path"
    echo "  --steps <fe/dc/sc/ac/all>   Steps to run (default: all)"
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --instance) num_instances="$2"; shift ;;
        --process) num_proc="$2"; shift ;;
        --domainsource) domain_source="$2"; shift ;;
        --domainfile) domain_file="$2"; shift ;;
        --build) build="$2"; shift ;;
        --cache) cache="$2"; shift ;;
        --verbos) verbos="$2"; shift ;;
        --steps) steps="$2"; shift ;;
        --sel) sel="$2"; shift ;;
        --mongo) mongo="$2"; shift ;;
        --directory) directory="$2"; shift ;;
        *) usage ;;
    esac
    shift
done


# Build feature extractor component
build_feature_extractor(){
  arch=$(uname -m)
  platform_option=""
  if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
    platform_option="--platform linux/x86_64"
  fi

  params=""
  if [ "$cache" == "yes" ]; then
    params=""
  else
    params="--no-cache"
  fi
  docker build $platform_option -t domain-feature-extractor:latest ./domain_feature_extractor $params

}

build_domain_classifier(){
  arch=$(uname -m)
  platform_option=""
  if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
    platform_option="--platform linux/x86_64"
  fi

  params=""
  if [ "$cache" == "yes" ]; then
    params=""
  else
    params="--no-cache"
  fi

  docker build $platform_option -t scamagnifier-domain-classifier:latest ./domain_classifier  $params

}

build_shop_classifier(){
  arch=$(uname -m)
  platform_option=""
  if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
    platform_option="--platform linux/x86_64"
  fi

  params=""
  if [ "$cache" == "yes" ]; then
    params=""
  else
    params="--no-cache"
  fi

  docker build $platform_option -t scamagnifier-shop-classifier:latest ./shop_classifier $params

}

build_autocheckout(){
  arch=$(uname -m)
  platform_option=""
  if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
    platform_option="--platform linux/x86_64"
  fi

  params=""
  if [ "$cache" == "yes" ]; then
    params=""
  else
    params="--no-cache"
  fi

  docker build $platform_option -t autocheck:latest ./autocheckout  $params

}


build_components() {
    if [ "$build" == "yes" ]; then
        docker compose build || handle_error "Failed to build components."
        build_feature_extractor || handle_error "Failed to build feature extracotr."
        build_domain_classifier || handle_error "Failed to build domain classifier."
        build_shop_classifier || handle_error "Failed to build shop classifier."
        build_autocheckout || handle_error "Failed to build ac."

    fi
}

run_service() {
    local service_name=$1
    local params=$2
    echo "Starting ${service_name} ${params} ..."
    docker compose up  ${service_name} ${params}
    if [ "$2" != "-d" ]; then
        local container_id=$(docker compose ps -q ${service_name})
        echo $container_id
        docker wait ${container_id}
        echo "${service_name} has completed."
    else
        echo "${service_name} has completed."
    fi
}

stop_service(){
    local service_name=$1
    echo "Stop $(service_name)..."
    docker compose down ${service_name}
}


start_domain_fetcher(){
  local _dir="$1"

  for i in $(seq 0 $((num_instances - 1)))
  do
      export SCAMAGNIFIER_DIR="$_dir"/"$i"
      container_path[i]="$_dir"/"$i"
      export JOB_NUMBER="$num_instances"
      export JOB_INDEX="$i"
      run_service scamagnifier-domain-fetcher
  done

}

start_domain_feed_db(){
  run_service scamagnifier-domain-feeder
}


# start feature extractor component
start_feature_extractor(){
  container_ids=()
  arch=$(uname -m)
  platform_option=""
  if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
    platform_option="--platform linux/x86_64"
  fi

  cpu_increment=${SCAMAGNIFIER_FE_CPU:-3}  

  params=""
  if [ "$verbos" == "yes" ]; then
    params=""
  else
    params="-d"
  fi

  for i in $(seq 0 $((num_instances - 1)))
  do
      let "cpu_start=i*4"
      let "cpu_end=cpu_start+cpu_increment"
      docker run $params $platform_option\
        --network app-network-scamagnifier \
        -v "$VOLUME_DIR":/app/data \
        -e SELENIUM_ADDRESS="$SCAMAGNIFIER_SELENIUM_ADDRESS:$SCAMAGNIFIER_SELENIUM_PORT" \
        -e NUMBER_PROC="$num_proc" \
        --name domain-feature-extractor-${i}-$RANDOM \
        --cpuset-cpus="${cpu_start}-${cpu_end}" \
        domain-feature-extractor \
        python ./src/app.py --selected_languages en --input_file /app/data/${container_path[i]}/domains.txt --source_path /app/data/${container_path[i]}/source_home --output_file /app/data/${container_path[i]}/features.pkl
      container_ids+=("$(docker ps -q -l)") 
      echo "feature_extractor: " ${container_path[i]}
  done

  for id in "${container_ids[@]}"; do
    docker wait "$id"
  done

  for id in "${container_ids[@]}"; do
    docker container rm "$id"
  done

}


start_domain_classifier(){
  container_ids=()
  arch=$(uname -m)
  platform_option=""
  if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
    platform_option="--platform linux/x86_64"
  fi
  cpu_increment=${SCAMAGNIFIER_DC_CPU:-3}  

  params=""
  if [ "$verbos" == "yes" ]; then
    params=""
  else
    params="-d"
  fi

  for i in $(seq 0 $((num_instances - 1)))
  do
  echo "domain_classifie: " ${container_path[i]}
  let "cpu_start=i*4"
  let "cpu_end=cpu_start+cpu_increment"

  docker run $params $platform_option\
    --network app-network-scamagnifier \
    -v "$VOLUME_DIR":/app/data \
    --name scamagnifier-domain-classifier-${i}-$RANDOM \
    --cpuset-cpus="${cpu_start}-${cpu_end}" \
    scamagnifier-domain-classifier \
    python ./src/app.py --input_file /app/data/${container_path[i]}/features.pkl --output_file /app/data/${container_path[i]}/classify.csv
  container_ids+=("$(docker ps -q -l)") 

  done

  for id in "${container_ids[@]}"; do
    docker wait "$id"
  done

  for id in "${container_ids[@]}"; do
    docker container rm "$id"
  done

}


start_shop_classifier(){
  container_ids=()
  arch=$(uname -m)
  platform_option=""
  if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
    platform_option="--platform linux/x86_64"
  fi
  cpu_increment=${SCAMAGNIFIER_SC_CPU:-3}  

  params=""
  if [ "$verbos" == "yes" ]; then
    params=""
  else
    params="-d"
  fi

  for i in $(seq 0 $((num_instances - 1)))
  do
  echo "start_shop_classifier: " ${container_path[i]}
  let "cpu_start=i*4"
  let "cpu_end=cpu_start+cpu_increment"

  docker run $params $platform_option\
      --network app-network-scamagnifier \
      -v "$VOLUME_DIR":/app/data \
      -e SELENIUM_ADDRESS="$SCAMAGNIFIER_SELENIUM_ADDRESS:$SCAMAGNIFIER_SELENIUM_PORT" \
      -e TRANSFORMERS_CACHE=/app/data/hf_cache/ \
      --name scamagnifier-shop-classifier-${i}-$RANDOM \
      --cpuset-cpus="${cpu_start}-${cpu_end}" \
      scamagnifier-shop-classifier \
      python ./src/app.py --input_dir /app/data/${container_path[i]}/source_home --input_file /app/data/${container_path[i]}/classify.csv --output_file /app/data/${container_path[i]}/shop.csv
  container_ids+=("$(docker ps -q -l)") 

  done

  for id in "${container_ids[@]}"; do
    docker wait "$id"
  done

  for id in "${container_ids[@]}"; do
    docker container rm "$id"
  done

}


start_auto_checkout(){
  container_ids=()
  arch=$(uname -m)
  platform_option=""
  if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
    platform_option="--platform linux/x86_64"
  fi
  cpu_increment=${SCAMAGNIFIER_AC_CPU:-3}  

  params=""
  if [ "$verbos" == "yes" ]; then
    params=""
  else
    params="-d"
  fi

  for i in $(seq 0 $((num_instances - 1)))
  do
  echo "start_auto_checkout: " ${container_path[i]}

  let "cpu_start=i*4"
  let "cpu_end=cpu_start+cpu_increment"

  docker run $params $platform_option\
      --network app-network-scamagnifier \
      -v "$VOLUME_DIR":/app/data \
      -e SELENIUM_ADDRESS="$SCAMAGNIFIER_SELENIUM_ADDRESS:$SCAMAGNIFIER_SELENIUM_PORT" \
      -e TRANSFORMERS_CACHE=/app/data/hf_cache/ \
      -e MONGO_USERNAME=${SCAMAGNIFIER_MONGO_NORMAL_USERNAME} \
      -e MONGO_PASSWORD=${SCAMAGNIFIER_MONGO_NORMAL_PASSWORD} \
      -e MONGO_HOSTNAME=${SCAMAGNIFIER_MONGO_HOST} \
      -e MONGO_PORT=${SCAMAGNIFIER_MONGO_PORT} \
      -e MONGO_DB=${SCAMAGNIFIER_MONGO_DB} \
      --name autocheck-${i}-$RANDOM \
      --cpuset-cpus="${cpu_start}-${cpu_end}" \
      autocheck \
      python ./src/app.py --input_file /app/data/${container_path[i]}/intersection.csv \
                        --log_file_address /app/data/${container_path[i]}/ \
                        --p_log_file_address /app/data/${container_path[i]}/log.jsonl \
                        --screen_file_address /app/data/${container_path[i]}/screenshots/ \
                        --html_file_address /app/data/${container_path[i]}/source_checkout/ \
                        --number_proc="$num_proc"  \
                        --filteredlist_log /app/data/${container_path[i]}/cros.log
  container_ids+=("$(docker ps -q -l)") 

  done

  for id in "${container_ids[@]}"; do
    docker wait "$id"
  done

  for id in "${container_ids[@]}"; do
    docker container rm "$id"
  done


}

copy_file_to_dir() {
    local file_path="$1"
    local target_dir="$2"

    if [ ! -f "$file_path" ]; then
        echo "File $file_path does not exist."
        return 1
    fi

    if [ ! -d "$target_dir" ]; then
        echo "Directory $target_dir does not exist."
        return 1
    fi

    cp "$file_path" "$target_dir"

        local target_file_path="$target_dir/domains.txt"
    mv "$target_dir/$(basename "$file_path")" "$target_file_path"

    echo "File $file_path copied and renamed to $target_file_path"

}

main() {
  # set env variable
  env_file_path="env.sh"
  if [ -f "$env_file_path" ]; then
      echo "File exists: $env_file_path"
      source ./env.sh
      check_env_vars
  else
      echo "env.sh File does not exist: $env_file_path"
      exit 1
  fi
  mkdir docker-entrypoint-initdb.d
  # build compoenet
  build_components

  # run selenoum
  if [ "$sel" == "yes" ]; then
    run_service selenium-grid -d
  fi

  source ./venv/bin/activate
  pip install -r requirements.txt

  if [ "$domain_source" == "db" ]; then
    # create a direcgtory for today
    today_dir=$(python ./src/dir_helper.py --numberofproc ${num_instances})
  else
    today_dir=$(python ./src/subdir_helper.py --directory ${directory})
  fi

  # fetch bdata
  if [ "$domain_source" == "db" ]; then
      
      if [ "$mongo" == "yes" ]; then
        chmod +x create_mongo_user.sh
        sh create_mongo_user.sh
        mv mongo-init.js ./docker-entrypoint-initdb.d/
        run_service mongodb -d
      fi

      if [ "$steps" == "all" ]; then
        start_domain_feed_db
        start_domain_fetcher "$today_dir"
      fi
      container_path[0]="$today_dir/0"
  elif [ "$domain_source" == "file" ]; then
      container_path[0]="$today_dir"
      copy_file_to_dir "$domain_file" "$VOLUME_DIR/$today_dir/"
  else
      handle_error "The domain source is not valid it should be db or file"
  fi

  case $steps in
      all)
          # Execute all steps
          start_feature_extractor
          start_domain_classifier
          start_shop_classifier
          if [ "$domain_source" == "db" ]; then
            python ./src/intersection_getter.py --input_bp "$VOLUME_DIR/$today_dir/0/classify.csv" --input_ec "$VOLUME_DIR/$today_dir/0/shop.csv" --output_file "$VOLUME_DIR/$today_dir/0/intersection.csv"
          else
            python ./src/intersection_getter.py --input_bp "$VOLUME_DIR/$today_dir/classify.csv" --input_ec "$VOLUME_DIR/$today_dir/shop.csv" --output_file "$VOLUME_DIR/$today_dir/intersection.csv"
          fi
          start_auto_checkout
          ;;
      fe)
          # Execute feature extractor
          start_feature_extractor
          ;;
      dc)
          # Execute domain classifier
          start_domain_classifier
          ;;
      sc)
          # Execute shop classifier
          start_shop_classifier
          ;;
      ac)
          # Execute auto checkout
          if [ "$domain_source" == "db" ]; then
            python ./src/intersection_getter.py --input_bp "$VOLUME_DIR/$today_dir/0/classify.csv" --input_ec "$VOLUME_DIR/$today_dir/0/shop.csv" --output_file "$VOLUME_DIR/$today_dir/0/intersection.csv"
          else
            python ./src/intersection_getter.py --input_bp "$VOLUME_DIR/$today_dir/classify.csv" --input_ec "$VOLUME_DIR/$today_dir/shop.csv" --output_file "$VOLUME_DIR/$today_dir/intersection.csv"
          fi
          start_auto_checkout
          ;;
      *)
          handle_error "Unknown step: $steps"
          ;;
  esac

  echo "All services have been processed."
  docker compose down
  deactivate
  echo "Stop all service ..."
}

main "$@"
