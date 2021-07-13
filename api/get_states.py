#!/usr/bin/python3

import os,sys,json
import pandas as pd

FILE = "synthea-source/src/main/resources/geography/demographics.csv"

if __name__ == "__main__":
    demo_df = pd.read_csv(FILE)
    states = demo_df['STNAME'].unique()
    with open("synthea-bin/STATES.txt","w") as f:
        for state in states:
            f.write(f"{state}\n")



