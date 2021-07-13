#!/usr/bin/python3

import requests
import pandas as pd
from datetime import datetime,timedelta
import os
from numpy import random


SCALING_FACTOR = 1
EPOCH_CONVERSION = 1000

endpoint = "https://data.cdc.gov/resource/ijqb-a7ye.json"

params = {
    "vaccine": "Exemption",
    "dose": "Non-Medical Exemption",
    "geography_type": "States",
    "$select":"geography,year_season,coverage_estimate,population_sample_size,number_of_exemptions"
}

def convert_schoolyear_to_epoch(
    year_str: str
) -> str:
    year_begin=year_str[0:4]
    birth_year = int(year_begin) - 6
    epoch = datetime(1970,1,1)
    epoch_start = (datetime(birth_year,6,1) - epoch).total_seconds()
    epoch_end = (datetime(birth_year+1,5,31) - epoch).total_seconds()
    return f"{int(epoch_start * EPOCH_CONVERSION)}-" \
        f"{int(epoch_end * EPOCH_CONVERSION)}"

# Create function to build measles infections csv
## Can use CDC data and Synthea city demographic data

cdc_measles_rates = {
    2010: 63,
    2011: 220,
    2012: 55,
    2013: 187,
    2014: 667,
    2015: 188,
    2016: 86,
    2017: 120,
    2018: 375,
    2019: 1282
}


if __name__ == "__main__":

    PROJECT_ROOT = os.environ.get('PROJECT_ROOT') or "../"
    result = requests.get(endpoint,params=params)

    demographics = pd.read_csv(
        os.path.join(
            PROJECT_ROOT,
            "synthea-source",
            "src",
            "main",
            "resources",
            "geography",
            "demographics.csv"
        )
    )

    measles_exposure = {
        "time":[],
        "city":[],
        "state":[],
        "Wait Until Exposure":[],
        "Call Infection Submodule":[],
        "Terminal":[]
    }

    for year in cdc_measles_rates:
        _ = 0
        p = 0
        used = []
        while (_ < 5000) and (p < cdc_measles_rates[year]):
            i = random.choice(range(demographics.shape[0]), p = \
                demographics['POPESTIMATE2015']/ \
                demographics['POPESTIMATE2015'].sum())
            while i in used:
                i = random.choice(range(demographics.shape[0]), p = \
                    demographics['POPESTIMATE2015']/ \
                    demographics['POPESTIMATE2015'].sum())
            used.append(i)
            st = demographics['STNAME'].iloc[i]
            city = demographics['NAME'].iloc[i]
            prob = random.sample()*0.2  # Make probabilities small (0.0 -- 0.2)
            t0 = (datetime(year,1,1) - datetime(1970,1,1)).total_seconds()
            t1 = t0 + 365*24*60*60*random.sample()
            t2 = t1 + 14*24*60*60 # two weeks
            measles_exposure['time'].append(
                f"{int(t1 * EPOCH_CONVERSION)}-"\
                    f"{int(t2 * EPOCH_CONVERSION)}"
            )
            measles_exposure['city'].append(city)
            measles_exposure['state'].append(st)
            measles_exposure['Wait Until Exposure'].append(1 - prob)
            measles_exposure['Call Infection Submodule'].append(prob)
            measles_exposure['Terminal'].append(0)
            _ += 1
            p += demographics['POPESTIMATE2015'].iloc[i] * prob * 0.00006

    measles_exposure_df = pd.DataFrame(measles_exposure)
    measles_exposure_df.to_csv(
        os.path.join(
            PROJECT_ROOT,
            "synthea-source",
            "src",
            "main",
            "resources",
            "modules",
            "lookup_tables",
            "measles_exposure.csv"
        ),
        index = False
    )

    data = result.json()
    nme_df = pd.DataFrame(data)
    nme_df.dropna(inplace=True)
    nme_df = nme_df.loc[nme_df['coverage_estimate'] != 'NA']

    nme_df.to_csv(
        os.path.join(
            PROJECT_ROOT,
            "data",
            "nme_by_state.csv"
        ),
        index = False
    )
    terminal = [(1 - v/100)**SCALING_FACTOR for v in \
                nme_df['coverage_estimate'].astype('float').values]
    output = pd.DataFrame(
        {
            "time": [convert_schoolyear_to_epoch(v) for \
                v in nme_df['year_season'].values
            ],
            "state": nme_df['geography'].values,
            "Terminal": terminal,
            "NME": [1-v for v in terminal]
        }
    )

    output.to_csv(
        os.path.join(
            PROJECT_ROOT,
            "synthea-source",
            "src",
            "main",
            "resources",
            "modules",
            "lookup_tables",
            "mmr_vaccine_prob.csv"
        ),
        index = False,
        float_format = "%0.2f"
    )

