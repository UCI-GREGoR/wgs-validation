# Snakemake workflow: WGS Validation

This workflow is intended to be a formal replacement for the _ad hoc_ validation system in place for the original research WGS pipeline circa 2020. The initial effort is designed to replicate as much of the feature set of the original validation schema as possible, but with testing and reproducibility. After that is accomplished, the feature set will be expanded to encompass the extra validation required for research whole genome data.

New global targets should be added in `workflow/Snakefile`. Content in `workflow/Snakefile` and the snakefiles in `workflow/rules` should be specifically _rules_; python infrastructure should be composed as subroutines under `lib/` and constructed in such a manner as to be testable with [pytest](https://docs.pytest.org/en/7.2.x/). Rules can call embedded scripts (in python or R/Rmd) from `workflow/scripts`; again, these should be constructed to be testable with pytest or [testthat](https://testthat.r-lib.org/).

## Authors

* Lightning Auriga (@lightning.auriga)

## Usage

### Step 1: Obtain a copy of this workflow

1. Clone this repository to your local system, into the place where you want to perform the data analysis.
```
    git clone git@gitlab.com:lightning.auriga1/wgs-validation.git
```

Note that this requires local git ssh key configuration; see [here](https://docs.gitlab.com/ee/user/ssh.html) for instructions as required.

### Step 2: Configure workflow

Configure the workflow according to your needs via editing the files in the `config/` folder. Adjust `config.yaml` to configure the workflow execution, and `manifest.tsv` to specify your sample setup.

The following settings are recognized in `config/config.yaml`.

- `experiment-manifest`: relative path to manifest of experimental vcfs
- `reference-manifest`: relative path to manifest of reference (i.e. "gold standard") vcfs
- `comparisons-manifest`: relative path to manifest of desired experimental/reference comparisons
- `happy-bedfiles-per-stratification`: how many stratification region sets should be dispatched to a single hap.py job. hap.py is a resource hog, and a relatively small number of stratification sets to the same run can cause it to explode. a setting of no more that 6 has worked in the past, though that was in a different setting
- `genome-build`: desired genome reference build for the comparisons. referenced by aliases specified in `genomes` block
- `genomes`: an arbitrary set of reference genome specifications. intended to be assigned tags such as `grch38`, `grch37`, etc. within each block:
  - `fasta`: path to genome fasta corresponding to this build. can be a path to a local file, or an http/ftp link, or an s3 path
  - `confident-regions`: arbitrarily many bedfiles describing a confident background on which comparison should be evaluated. bedfiles are specified in `key: value` pairs, with the key a unique identifier labeling the region type, and the value the path to the bedfile. if multiple `key: value` pairs are provided, they will all be used in turn as backgrounds for each of the requested comparisons. AY bedfiles might be specified here
  - `stratification-regions`: intended to be the GIAB stratification regions, as described [here](https://github.com/genome-in-a-bottle/genome-stratifications). the remote directory will be mirrored locally with lftp. these entries are specified as:
    - `ftp`: the ftp hosting site
	- `dir`: the subdirectory of the ftp hosting site, through the genome build directory


The following columns are expected in the experiment manifest, by default at `config/manifest_experiment.tsv`:
- `experimental_dataset`: arbitrary, unique alias for this experimental dataset
- `replicate`: identifier linking experimental subjects representing the same underlying sample and conditions. this identifier will be used to collapse multiple subjects into single mean/SE estimates in the downstream report, if multiple subjects with the same identifier are included in the same report
- `vcf`: path to experimental dataset vcf

The following columns are expected in the reference manifest, by default at `config/manifest_reference.tsv`:
- `reference_dataset`: arbitrary, unique alias for this reference dataset
- `vcf`: path to reference dataset vcf

The following columns are expected in the comparisons manifest, by default at `config/manifest_comparisons.tsv`:
- `experimental_dataset`: experimental dataset for this comparison, referenced by unique alias
- `reference_dataset`: reference dataset for this comparison, referenced by unique alias
- `report`: unique identifier labeling which report this comparison should be included in. multiple can be specified, in a comma-delimited list

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

TBD. This will be expanded once it becomes clearer to me what the expectations of this pipeline truly are.

### Step 6: Commit changes

Whenever you change something, don't forget to commit the changes back to your github copy of the repository:

    git commit -a
    git push

### Step 7: Obtain updates from upstream

Whenever you want to synchronize your workflow copy with new developments from upstream, do the following.

1. Once, register the upstream repository in your local copy: `git remote add -f upstream git@gitlab.com:lightning.auriga1/wgs-validation.git` or `upstream https://gitlab.com/lightning.auriga1/wgs-validation.git` if you do not have setup ssh keys.
2. Update the upstream version: `git fetch upstream`.
3. Create a diff with the current version: `git diff HEAD upstream/default workflow > upstream-changes.diff`.
4. Investigate the changes: `vim upstream-changes.diff`.
5. Apply the modified diff via: `git apply upstream-changes.diff`.
6. Carefully check whether you need to update the config files: `git diff HEAD upstream/default config`. If so, do it manually, and only where necessary, since you would otherwise likely overwrite your settings and samples.


### Step 8: Contribute back

In case you have also changed or added steps, please consider contributing them back to the original repository. This project follows git flow; feature branches off of dev are welcome.

1. [Clone](https://docs.gitlab.com/ee/gitlab-basics/start-using-git.html) the fork to your local system, to a different place than where you ran your analysis.
2. Check out a branch off of dev:
```
git fetch
git checkout dev
git checkout -b your-new-branch
```
3. Make whatever changes best please you to your feature branch.
4. Commit and push your changes to your branch.
5. Create a [merge request](https://docs.gitlab.com/ee/user/project/merge_requests/) against dev.

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
