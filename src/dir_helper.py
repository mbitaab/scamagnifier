import os
import datetime
from config import *
import argparse

def create_html_dir(_proc_number):
    # Get current date
    date = datetime.datetime.now()
    year = date.year
    month = date.month  # Note the correction from "mounth" to "month"
    day = date.day

    # Base directory from environment variable
    dir = volume_dir

    # Check if base directory exists, if not, try to create it
    if not os.path.exists(dir):
        try:
            os.makedirs(dir)
        except Exception as ex:
            pass  # Exception handling can be improved based on needs

    # Append "/files_html" to the directory and check again
    dir = os.path.join(dir, 'scam_magnifier')
    if not os.path.exists(dir):
        try:
            os.makedirs(dir)
        except Exception as ex:
            pass

    # Append "/year" to the directory and check again
    dir = os.path.join(dir, str(year))
    if not os.path.exists(dir):
        try:
            os.makedirs(dir)
        except Exception as ex:
            pass

    # Append "/month" to the directory and check again
    dir = os.path.join(dir, str(month))
    if not os.path.exists(dir):
        try:
            os.makedirs(dir)
        except Exception as ex:
            pass

    # Append "/day" to the directory and check again
    dir = os.path.join(dir, str(day))
    if not os.path.exists(dir):
        try:
            os.makedirs(dir)
        except Exception as ex:
            pass
    
    for index in range(_proc_number):
        try:
            os.makedirs(dir + os.sep+str(index))
            os.makedirs(dir + os.sep+str(index) + os.sep+"source_home")
            os.makedirs(dir + os.sep+str(index) + os.sep+"screenshots")
            os.makedirs(dir + os.sep+str(index) + os.sep+"source_checkout")
        except Exception as ex:
            pass
    return dir.replace(volume_dir+ os.sep,"")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='')
    parser.add_argument('--numberofproc', type=int, help='number of process', required=True)
    args = parser.parse_args()
    print(create_html_dir(args.numberofproc))