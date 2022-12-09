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
            "grch100": {"confident-regions": {"reg3": "file3", "reg4": "file4"}},
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
    res = pd.DataFrame({"experimental_dataset": [], "replicate": [], "vcf": []})
    return res


@pytest.fixture
def manifest_reference():
    """
    pandas DataFrame of configured reference vcf files
    with unique identifier
    """
    res = pd.DataFrame({"reference_dataset": [], "vcf": []})
    return res


@pytest.fixture
def wildcards_for_report():
    """
    Namedlist containing wildcards present in
    Rmd report generation rule
    """
    return Namedlist(fromdict={"comparison": "comp2", "region": "back1"})
