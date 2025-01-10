# Scamagnifier

## Overview
Scamagnifier is a multi-stage pipeline container service designed for the analysis and classification of newly registered domains. Each stage of the pipeline is added as a submodule to the project, coordinated with `docker-compose` and a shell script to manage execution flow.

## Project Details

### Services
The project utilizes the following services:

- **MongoDB**: Used to store data on newly registered domains each day.
- **Selenium Grid**: Facilitates the crawling of domains, saving of pages, and automating the checkout process.

### Pipeline Stages
The pipeline consists of several stages, each with a specific function:

1. **Domain Feeder**: Fetches newly registered domains from WHOIS and stores them in MongoDB.
2. **Domain Fetcher**: Queries the database to retrieve domains for a specific date, storing them in a file for subsequent pipeline processing.
3. **Domain Feature Extractor**: Crawls each domain using Selenium, stores the homepage in a directory, and extracts the desired features.
4. **Domain Classifier**: Takes the features extracted in the previous step to identify active domains.
5. **Shop Classifier**: Filters out domains of shopping sites.
6. **Autocheckout**: The final stage, where shopping site domains are processed to automate the checkout process. This involves identifying purchasable products on the site, adding them to the basket, and attempting to purchase them, with the goal of automatically extracting the merchant ID.

## Getting Started

To get started with Scamagnifier, follow these steps:

1. Ensure you have Docker and Docker Compose installed on your system.
2. Clone the project repository to your local machine, including all submodules, with the following command:
   ```sh
    git clone --recursive git@github.com:mbitaab/scamagnifier.git
    ```
3. Navigate to the project directory.
4. Navigate to the project directory.**
```sh
export EXP_DIR=<A shared volume used to store data>
export EXP_MONGO=<A directory used to store MongoDB data>
export SCAMAGNIFIER_DATE=$(date -d '16 days ago' +"%Y-%m-%d")T00:00:00.000$(date +%:z)
```
Replace <A shared volume used to store data> and <A directory used to store MongoDB data> with the actual paths you wish to use for storing your data.
Here, 16 days ago sets the hold period for domains in the database before they are crawled. Replace this value if you wish to change the hold period.
5. Make the env.sh file executable:
```sh
chmod +x env.sh
```
6. Run the pipeline using the provided shell script:
```sh
pipline_1.sh --process 48 --domainsource file --domainfile <ADDRESS_OF_DOMAINS_FILE> --steps all           
```
## Additional Info
Selenium-grid console is accessable through:
```sh
http://<YOUR-IP-ADDRESS>:4451
```


## Contributing

Contributions to Scamagnifier are welcome. Please follow the standard fork and pull request workflow to submit your changes for review.

## License
