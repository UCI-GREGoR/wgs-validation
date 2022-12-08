import os
from math import ceil

import pandas as pd
from snakemake.io import AnnotatedString, Namedlist, expand
from snakemake.remote.FTP import RemoteProvider as FTPRemoteProvider
from snakemake.remote.HTTP import RemoteProvider as HTTPRemoteProvider
from snakemake.remote.S3 import RemoteProvider as S3RemoteProvider

FTP = FTPRemoteProvider()
S3 = S3RemoteProvider()
HTTP = HTTPRemoteProvider()


def wrap_remote_file(fn: str) -> str | AnnotatedString:
    """
    Given a filename, potentially wrap it in a remote handler
    """
    mapped_name = fn
    if mapped_name.startswith("s3://"):
        return S3.remote(mapped_name)
    elif mapped_name.startswith("https://") or mapped_name.startswith("http://"):
        return HTTP.remote(mapped_name)
    elif mapped_name.startswith("ftp://"):
        return FTP.remote(mapped_name)
    return mapped_name


def get_happy_output_files(
    wildcards,
    manifest_comparisons: pd.DataFrame,
) -> list:
    """
    Use configuration and manifest data to generate the set of comparisons
    required for a full complement of hap.py runs.

    Comparisons are specified as rows in manifest_comparisons. The entries in those
    two columns *should* exist as indices in the corresponding other manifests.
    """
    res = []
    for reference, experimental, report in zip(
        manifest_comparisons["reference_dataset"],
        manifest_comparisons["experimental_dataset"],
        manifest_comparisons["report"],
    ):
        if wildcards.comparison in report.split(","):
            res.append(
                "results/happy/{}/{}/{}/results.summary.csv".format(
                    experimental, reference, wildcards.region
                )
            )
    return res


def construct_targets(config, manifest: pd.DataFrame) -> list:
    """
    Use comparison manifest data to generate the set of comparisons
    required for a full pipeline run.
    """
    comparisons = [x.split(",") for x in manifest["report"]]
    comparisons = [x for y in comparisons for x in y]
    regions = list(config["genomes"][config["genome-build"]]["confident-regions"].keys())
    res = expand(
        "results/reports/control_validation_comparison-{comparison}_vs_region-{region}.html",
        comparison=comparisons,
        region=regions,
    )
    return res


def map_reference_file(wildcards: Namedlist, manifest: pd.DataFrame) -> str | AnnotatedString:
    """
    Probe the prefix of a filename to determine which sort of
    remote provider (if any) should be used to acquire a local copy.

    Reference vcfs are pulled from the relevant column in the manifest.
    """
    ## The intention for this function was to distinguish between S3 file paths and others,
    ## and return wrapped objects related to the remote provider service when appropriate.
    ## There have been periodic issues with the remote provider interface, but it seems
    ## to be working, somewhat inefficiently but very conveniently, for the time being.
    mapped_name = manifest.loc[wildcards.reference, "vcf"]
    return wrap_remote_file(mapped_name)


def map_experimental_file(wildcards: Namedlist, manifest: pd.DataFrame) -> str | AnnotatedString:
    """
    Probe the prefix of a filename to determine which sort of
    remote provider (if any) should be used to acquire a local copy.

    Experimental vcfs are pulled from the relevant column in the manifest.
    """
    ## The intention for this function was to distinguish between S3 file paths and others,
    ## and return wrapped objects related to the remote provider service when appropriate.
    ## There have been periodic issues with the remote provider interface, but it seems
    ## to be working, somewhat inefficiently but very conveniently, for the time being.
    mapped_name = manifest.loc[wildcards.experimental, "vcf"]
    return wrap_remote_file(mapped_name)


def get_happy_stratification_by_index(wildcards, config, checkpoints):
    """
    Given the index of a stratification region in its original annotation file,
    return the list of implicated entries.
    """
    beds_per_set = config["happy-bedfiles-per-stratification"]
    regions = []
    with open(
        checkpoints.get_stratification_bedfiles.get(genome_build=config["genome-build"]).output[0],
        "r",
    ) as f:
        regions = f.readlines()
    lines = [
        regions[i]
        for i in range(
            int(wildcards.stratification_set) * beds_per_set,
            min((int(wildcards.stratification_set) + 1) * beds_per_set, len(regions)),
        )
    ]
    return lines


def get_happy_stratification_set_indices(wildcards, config, checkpoints):
    """
    Given the checkpoint output of stratification region download, get a list of indices that can
    be used as intermediate names for the region files during DAG construction.
    """
    beds_per_set = config["happy-bedfiles-per-stratification"]
    regions = []
    with open(
        checkpoints.get_stratification_bedfiles.get(genome_build=config["genome-build"]).output[0],
        "r",
    ) as f:
        regions = f.readlines()
    return [x for x in range(ceil(len(regions) / beds_per_set))]
