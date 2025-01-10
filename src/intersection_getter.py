import pandas as pd
import argparse
import re



def clean_url(url):
    # Regular expression pattern to match and remove the desired prefixes
    pattern = re.compile(r'^(http:\/\/|https:\/\/|www\.)+')
    # Replace the matched prefixes with an empty string
    cleaned_url = re.sub(pattern, '', url)
    return cleaned_url

def main(args):
    df_scam = pd.read_csv(args.input_bp)
    df_scam['URL'] = df_scam['URL'].apply(clean_url)
    print(df_scam.head())
    df_shop = pd.read_csv(args.input_ec)
    df_shop['URL'] = df_shop['URL'].apply(clean_url)
    print(df_shop.head())
    df_filtered = df_scam[df_scam['Label'] == 'scam'].merge(df_shop[df_shop['label'] == 'shop'], on='URL')
    df_filtered['URL'].to_csv(args.output_file, index=False)
    print('df filtered length: %s' %len(df_filtered))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Optional app description')

    parser.add_argument('--input_bp', type=str, help='input file BP result', required=True)
    parser.add_argument('--input_ec', type=str, help='input txt/json of urls', required=True)
    parser.add_argument('--output_file', type=str, help='output file', required=True)

    args = parser.parse_args()
    main(args)
