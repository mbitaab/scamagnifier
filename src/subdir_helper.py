import os
import argparse
from config import *

def create_html_dir(directory):
    dir = directory
    
    try:
        if not os.path.exists(dir +  os.sep+"source_home"):
            os.makedirs(dir + os.sep+"source_home")
        
        if not os.path.exists(dir + os.sep+"screenshots"):
            os.makedirs(dir + os.sep+"screenshots")
    
        if not os.path.exists(dir + os.sep+"source_checkout"):
            os.makedirs(dir + os.sep+"source_checkout")
    except Exception as ex:
        pass

    return dir.replace(volume_dir+ os.sep,"")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='')
    parser.add_argument('--directory', type=str, help='directory', required=True)
    args = parser.parse_args()
    print(create_html_dir(args.directory))