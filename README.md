# Snakemake workflow: WGS Validation

[![CircleCI](https://dl.circleci.com/status-badge/img/gh/UCI-GREGoR/wgs-validation/tree/default.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/UCI-GREGoR/wgs-validation/tree/default)

[![codecov](https://codecov.io/gh/UCI-GREGoR/wgs-validation/graph/badge.svg?token=SLLOZX9Y3B)](https://codecov.io/gh/UCI-GREGoR/wgs-validation)

This workflow is intended to formally replace _ad hoc_ whole genome sequencing validation workflows using manual or cumbersome invocations of [hap.py](https://github.com/Illumina/hap.py) or equivalent tooling. Separate but analogous support is provided for SNVs and SVs. As SV validation is not standardized in the field as a whole, various implementations of SV validation heuristics are supported to mimic the behavior of various prominent publications.

New global targets should be added in `workflow/Snakefile`. Content in `workflow/Snakefile` and the snakefiles in `workflow/rules` should be specifically _rules_; python infrastructure should be composed as subroutines under `lib/` and constructed in such a manner as to be testable with [pytest](https://docs.pytest.org/en/7.2.x/). Rules can call embedded scripts (in python or R/Rmd) from `workflow/scripts`; again, these should be constructed to be testable with pytest or [testthat](https://testthat.r-lib.org/).

## Authors

* Lightning Auriga (@lightning-auriga)

## Usage

### Step 1: Obtain a copy of this workflow

1. Clone this repository to your local system, into the place where you want to perform the data analysis.
```
    git clone git@github.com:UCI-GREGoR/wgs-validation.git
```

Note that this requires local git ssh key configuration; see [here](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account) for instructions as required.

### Step 2: Configure workflow

Configure the workflow according to your needs via editing the files in the `config/` folder. Adjust `config.yaml` to configure the workflow execution, and `manifest.tsv` to specify your sample setup.

#### General Run Configuration

The following settings are recognized in `config/config.yaml`.

|Configuration Setting|Description|
|---|---|
|`experiment-manifest`|relative path to manifest of experimental vcfs|
|`reference-manifest`|relative path to manifest of reference (i.e. "gold standard") vcfs|
|`comparisons-manifest`|relative path to manifest of desired experimental/reference comparisons|
|`happy-bedfiles-per-stratification`|how many stratification region sets should be dispatched to a single hap.py job. hap.py is a resource hog, and a relatively small number of stratification sets to the same run can cause it to explode. a setting of no more that 6 has worked in the past, though that was in a different setting|
|`sv-settings`|configuration settings for SV comparisons and SV-specific tools|
||`merge-experimental-before-comparison`: whether to use SVDB to combine variants within a single experimental sample vcf before comparison|
||`merge-reference-before-comparison`: whether to use SVDB to combine variants within a single reference sample vcf before comparison
||`svanalyzer`: settings specific to `svanalyzer`. see [svanalyzer project](https://github.com/nhansen/SVanalyzer/blob/master/docs/svbenchmark.rst) for parameter documentation|
||`svdb`: settings specific to `svdb`. see [svdb project](https://github.com/J35P312/SVDB#merge) for parameter documentation|
||`sveval`: settings specific to `sveval`. see [sveval project](https://github.com/jmonlong/sveval) for parameter documentation|
|`genome-build`|desired genome reference build for the comparisons. referenced by aliases specified in `genomes` block|



The `genomes` block of the configuration file contains an arbitrary set of genome specifications. The intention is that the
blocks specified under this tag are assigned keys such as `grch38`, `grch37`, etc. The following settings are specified
under each block:

|Configuration Setting|Description|
|---|---|
|`fasta`|path to genome fasta corresponding to this build. can be a path to a local file, or an http/ftp link, or an s3 path|
|`confident-regions`|arbitrarily many bedfiles describing a confident background on which comparison should be evaluated. the names under `confident-regions` are unique identifiers labeling the region type, and contain the following key/value pairs|
||`bed`: bed regions in which to compute calculations. high-confidence GIAB background bedfiles can be specified here|
||`inclusion`: (optional) a regex to match against experimental replicate entry in manifest (see below). only reports containing samples matching this pattern will be run against these confident regions. if not included, this region is used for all reports|
|`stratification-regions`|intended to be the GIAB stratification regions, as described [here](https://github.com/genome-in-a-bottle/genome-stratifications). the remote directory will be mirrored locally. these entries are specified as:|
||`ftp`: the ftp hosting site|
||`dir`: the subdirectory of the ftp hosting site, through the genome build directory|
||`region-labels`: a manifest of GA4GH-style stratification regions, with short name of region and corresponding human-legible description of the content of the region. see below for how these should be selected in the workflow|

#### Selecting Stratification Regions

hap.py and similar tools are designed to compute both overall metrics and metrics within specific subdivisions of the genome. These divisions can be anything, but are most commonly framed as [genome stratifications](https://github.com/genome-in-a-bottle/genome-stratifications) containing different types of variation that can be challenging for WGS calling tools.

The GA4GH stratification regions referenced above are numerous, and many of those regions aren't particularly interesting or interpretable. Furthermore, hap.py is resource-intensive, and computing superfluous comparisons that won't be analyzed is undesirable. As such, this workflow requires the user to select individual stratification sets for inclusion in the output reports. The inclusions are specified as key-value pairs in `config/config.yaml` under the configuration key `genomes/{genome-build}/stratification-regions/region-inclusions`. The keys are names of regions as specified in the corresponding `region-labels` manifest; the values are regular expressions describing the sample identifiers that should be evaluated within those regions. To select all samples, use the regular expression `"^.*$"`.

As an example:

```yaml
genomes:
    grch38:
        stratification-regions:
            region-inclusions:
                "*": ".*"
                "alldifficultregions": ".*NA12878.*"
```

#### Run Manifests

The following columns are expected in the experiment manifest, by default at `config/manifest_experiment.tsv`:

|Manifest Entry|Description|
|---|---|
|`experimental_dataset`|arbitrary identifier for this dataset|
|`replicate`|identifier linking experimental subjects representing the same underlying sample and conditions. this identifier will be used to collapse multiple subjects into single mean/SE estimates in the downstream report, if multiple subjects with the same identifier are included in the same report|
|`vcf`|path to experimental dataset vcf|

Note that for the experimental manifest, multiple rows with the same `experimental_dataset` value can be included with different corresponding vcfs. If this is the case, the multiple vcfs will be concatenated and sorted into a single vcf before validation. The intended use case of this functionality is on-the-fly concatenation of single chromosome vcfs per sample.

The following columns are expected in the reference manifest, by default at `config/manifest_reference.tsv`:

|Manifest Entry|Description|
|---|---|
|`reference_dataset`|arbitrary, unique alias for this reference dataset|
|`vcf`|path to reference dataset vcf|

The following columns are expected in the comparisons manifest, by default at `config/manifest_comparisons.tsv`:

|Manifest Entry|Description|
|---|---|
|`experimental_dataset`|experimental dataset for this comparison, referenced by unique alias|
|`reference_dataset`|reference dataset for this comparison, referenced by unique alias|
|`report`|unique identifier labeling which report this comparison should be included in. multiple can be specified, in a comma-delimited list|

Note that the entries in individual columns of the comparisons manifest are not intended to be unique, so
multiple comparisons involving the same file are expected.

### Step 3: Install Snakemake

Install Snakemake using [conda](https://conda.io/projects/conda/en/latest/user-guide/install/index.html):

    conda create -c bioconda -c conda-forge -n snakemake snakemake

For installation details, see the [instructions in the Snakemake documentation](https://snakemake.readthedocs.io/en/stable/getting_started/installation.html).

### Step 4: Execute workflow

Activate the conda environment:

    conda activate snakemake

Test your configuration by performing a dry-run via

    snakemake --use-conda -n

Execute the workflow locally via

    snakemake --use-conda --cores $N

using `$N` cores or run it in a cluster environment via

    snakemake --use-conda --profile sge-profile --cluster-config config/cluster.yaml --jobs 100

See the [Snakemake documentation](https://snakemake.readthedocs.io/en/stable/executable.html) for further details.

#### Cluster profiles

Snakemake interfaces with job schedulers via _cluster profiles_. For running jobs on SGE, you can use
the cookiecutter template [here](https://github.com/Snakemake-Profiles/sge).



### Step 5: Investigate results

After the completion of a run, there will be control validation reports, in html format, at `results/reports`.
One report will exist per configured comparison, in `config/manifest_comparisons.tsv` column `report`.
The contents of the report are:

- tabular summaries of requested stratification regions from the configuration
- plots of requested stratification regions from the configuration
- summary information about the R execution environment used to create the report

Other information will be included in future versions.

### Step 6: Commit changes

Whenever you change something, don't forget to commit the changes back to your github copy of the repository:

    git commit -a
    git push

### Step 7: Obtain updates from upstream

Whenever you want to synchronize your workflow copy with new developments from upstream, do the following.

1. Once, register the upstream repository in your local copy: `git remote add -f upstream git@github.com/UCI-GREGoR/wgs-validation.git` or `upstream https://github.com/UCI-GREGoR/wgs-validation.git` if you do not have setup ssh keys.
2. Update the upstream version: `git fetch upstream`.
3. Create a diff with the current version: `git diff HEAD upstream/default workflow > upstream-changes.diff`.
4. Investigate the changes: `vim upstream-changes.diff`.
5. Apply the modified diff via: `git apply upstream-changes.diff`.
6. Carefully check whether you need to update the config files: `git diff HEAD upstream/default config`. If so, do it manually, and only where necessary, since you would otherwise likely overwrite your settings and samples.


### Step 8: Contribute back

In case you have also changed or added steps, please consider contributing them back to the original repository. This project follows git flow; feature branches off of dev are welcome.

1. [Clone](https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository) the fork to your local system, to a different place than where you ran your analysis.
2. Check out a branch off of dev:
```
git fetch
git checkout dev
git checkout -b your-new-branch
```
3. Make whatever changes best please you to your feature branch.
4. Commit and push your changes to your branch.
5. Create a [pull request](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests) against dev.

## Testing

Testing infrastructure for embedded python and R scripts is installed under `lib/` and `workflow/scripts/`. Additional testing
coverage for the Snakemake infrastructure itself should be added once the workflow is more mature ([see here](https://github.com/lightning-auriga/snakemake-unit-tests)).

### Python testing with `pytest`
The testing under `lib/` is currently functional. Partial testing exists for the builtin scripts under `workflow/scripts`: the new utilities
for this implementation are tested, but some code inherited from the legacy pipeline(s) is not yet covered. To run the tests, do the following (from top level):

```bash
mamba install pytest-cov
pytest --cov=lib --cov=workflow/scripts lib workflow/scripts
```


### R testing with `testthat`
The testing under `workflow/scripts` is currently functional. The tests can be run with the utility script `run_tests.R`:

```bash
Rscript ./run_tests.R
```

To execute the above command, the environment must have an instance of R with appropriate libraries:

```bash
mamba install -c bioconda -c conda-forge "r-base>=4" r-testthat r-covr r-r.utils r-desctools
```
