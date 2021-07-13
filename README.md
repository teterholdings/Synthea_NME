# Modeling Vaccine Non-medical Exemptions (NMEs) in Synthea

This repository contains a prototype implementation of the ability to capture non-medical exemptions to vaccines in [Synthea](https://github.com/synthetichealth/synthea).  This is part of Team TeMa's submission to the [Synthetic Health Data Challenge](https://www.challenge.gov/challenge/synthetic-health-data-challenge/).


# Abstract

Recent trends have shown an increase in the number of parents that request non-medical exemptions (NMEs) to routine pediatric vaccinations.  The resulting decline in childhood vaccinations has led to increases in childhood disease outbreaks.  In its current form, Synthea does not account for these variations in pediatric vaccinations, which are the result of patient health care preferences that do not align with accepted optimal approaches to health care. 

For this effort, we modify the existing immunization workflow in Synthea so that it accounts for patient preferences and produces synthetic health records (or synthetic patients) with a more varied vaccination history, specifically with respect to the Measles, Mumps, and Rubella (MMR) vaccine.  We demonstrate the utility of this modification by developing a prototype module for childhood measles that is responsive to whether the patient has received the MMR vaccination.  To validate the results, we use linear regression compare the synthetic data produced to existing public vaccination estimates.  Finally, we comment on how this development enhances the capability of Synthea and propose multiple avenues for future research efforts that, using this capability, could have significant impacts on public health and facilitate Patient Centered Outcomes Research (PCOR).

More information is contained in our project report, located in this repository at `write-up/submission.pdf`.

# What this code does

This code makes some modifications to the Synthea base code in order to produce patient records that elect to take a non-medical exemption for some pediatric vaccines.  We provide a measles module and measles-infection submodule that use this capability, producing patient records with no MMR vaccine.  Some of these patients also develop Measles.  

We also use open source software to develop some analytic tools that investigate and validate the outputs of these modifications, including:
* Interactive heat maps of NME rates and Measles Infections.
* Regression plots to validate synthetic NME rates against known NME rates.
* Bar plots of total infections over time.

# Implementation

## Requirements

1. Synthea developer requirements (access to Synthea source code, java compiler, gradle, etc.)  See [Synthea Developer Setup](https://github.com/synthetichealth/synthea/wiki/Developer-Setup-and-Running).
1. Python 3 and python virtual environment.
1. Docker installed and running.

## Steps

These step-by-step instructions assume a unix-like shell, e.g., bash.

### Clone the repository and change into it.

```bash
git clone https://github.com/teterholdings/Synthea_NME
cd Synthea_NME
```

### Set up the environment

Set a `PROJECT_ROOT` environment variables, and set-up our python virtual environment.

```bash
export PROJECT_ROOT=$(pwd)
python3 -m venv env
source env/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

### Clone Synthea (if it doesn't already exist)

```bash
if [ ! -d "synthea-source" ]; then
  git clone https://github.com/synthetichealth/synthea.git synthea-source
fi
```

### Modify `Immunizations.java` module

For simplicity, we'll use `sed` to replace the line
```
    if (series > 0) {
```
with the line
```
    if ((series > 0) && !person.attributes.containsKey(immunization + " NME")) {
```

If the command below does not work, you can make the line replacement in `Immunizations.java` manually.
```bash
sed -i 's/if (series > 0) {/if ((series > 0) \&\& \!person\.attributes\.containsKey(immunization + " NME")) {/g' synthea-source/src/main/java/org/mitre/synthea/modules/Immunizations.java
```

### Copy measles module and measles-infection submodule into source code

```bash
cp -R modules/measles synthea-source/src/main/resources/modules/
cp modules/measles.json synthea-source/src/main/resources/modules
```

### Generate lookup tables

The `api/build_lookups.py` generates the lookup tables and saves them in the correct place in the source code.  In practice, a user should generate lookup tables to model and analyze an NME scenario of interest.

```bash
python api/build_lookups.py
```

### Build Synthea

Change into the Synthea source folder and use gradle to build the jarfile with dependencies.  Copy the resulting jarfile to the `$PROJECT_ROOT` directory.

```bash
cd synthea-source
./gradle build uberJar
cp build/libs/synthea-with-dependencies.jar $PROJECT_ROOT/
cd ..
```

### Run Synthea to generate records for all states

Generate `$RECORD_COUNT` (50 in below script) records and save to `data/` folder.  Age range is set for 6-30 years old to capture the target NME demographic.

```bash
export RECORD_COUNT=50

while IFS="" read -r p || [ -n "$p" ]
do
	java -jar $PROJECT_ROOT/synthea-with-dependencies.jar \
	-p $RECORD_COUNT \
	-m "measles*" \
	--exporter.baseDirectory $PROJECT_ROOT/data/ \
	--exporter.symptoms.mode 1 \
	--exporter.symptoms.csv.export true \
	--exporter.years_of_history 0 \
	-a 6-30 \
	$p
done < $PROJECT_ROOT/data/STATES.txt
```

### Run the analysis script

The analysis script uses R, but for this project we have used Docker in order to minimize dependencies that must be installed locally.

```bash
docker build -t mapper $PROJECT_ROOT/mapper

docker run --rm -v $PROJECT_ROOT/data:/data \
    -v $PROJECT_ROOT/plots:/output \
    mapper
```

### Analyze results

The Docker `mapper` executable uses R to create interactive maps, bar plots, and scatter/regression plots for validation and analysis.  Per the project paper, small populations of records do represent the low density occurrences of NMEs and measles infections well.

