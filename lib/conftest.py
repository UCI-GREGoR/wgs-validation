import pandas as pd
import pytest
from snakemake.io import Namedlist


@pytest.fixture
def config():
    """
    dict containing configuration data for run
    """
    res = {
        "genome-build": "grch100",
        "genomes": {
            "grch99": {"confident-regions": {"reg1": "file1", "reg2": "file2"}},
            "grch100": {
                "confident-regions": {"reg3": "file3", "reg4": "file4"},
                "stratification-regions": {
                    "ftp": "ftp://target",
                    "dir": "ftpdir",
                    "all-stratifications": "vWhatever.all-stratifications.tsv",
                    "region-definitions": [
                        {"name": "*", "label": "everybody", "inclusion": ".*"},
                        {"name": "name1", "label": "some1", "inclusion": ".*"},
                        {"name": "name2", "label": "some2", "inclusion": ".*"},
                    ],
                },
            },
        },
    }
    return res


@pytest.fixture
def manifest_comparisons():
    """
    pandas DataFrame of configured requested comparisons
    between experimental and reference datasets
    """
    res = pd.DataFrame(
        {
            "experimental_dataset": ["exp1", "exp1", "exp2", "exp2"],
            "reference_dataset": ["ref1", "ref2", "ref1", "ref2"],
            "report": ["comp2", "comp2,comp1", "comp3", "comp3,comp1"],
        }
    )
    return res


@pytest.fixture
def manifest_experiment():
    """
    pandas DataFrame of configured experimental vcf files
    with replicate and unique identifier
    """
    res = pd.DataFrame(
        {
            "happy-bedfiles-for-stratification": 3,
            "experimental_dataset": ["exp1", "exp2", "exp3"],
            "replicate": ["rep1", "rep1", "rep2"],
            "vcf": ["dummy/path1.vcf.gz", "dummy/path2.vcf.gz", "path/to/exp_filename.vcf.gz"],
        }
    ).set_index("experimental_dataset", drop=False)
    return res


@pytest.fixture
def manifest_reference():
    """
    pandas DataFrame of configured reference vcf files
    with unique identifier
    """
    res = pd.DataFrame(
        {
            "reference_dataset": ["ref1", "ref2", "ref3"],
            "vcf": ["dummy/path3.vcf.gz", "path/to/ref_filename.vcf.gz", "dummy/path4.vcf.gz"],
        }
    ).set_index("reference_dataset", drop=False)
    return res


@pytest.fixture
def wildcards_for_report():
    """
    Namedlist containing wildcards present in
    Rmd report generation rule
    """
    return Namedlist(fromdict={"comparison": "comp2", "region": "back1"})


@pytest.fixture
def wildcards_comparison():
    """
    Namedlist containing wildcards present for
    a rule that needs to map from unique identifier to vcf
    """
    return Namedlist(fromdict={"reference": "ref2", "experimental": "exp3"})
