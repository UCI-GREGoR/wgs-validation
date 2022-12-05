import os

import pandas as pd
from snakemake.io import AnnotatedString, Namedlist
from snakemake.remote.FTP import RemoteProvider as FTPRemoteProvider
from snakemake.remote.HTTP import RemoteProvider as HTTPRemoteProvider
from snakemake.remote.S3 import RemoteProvider as S3RemoteProvider

FTP = FTPRemoteProvider()
S3 = S3RemoteProvider()
HTTP = HTTPRemoteProvider()


def construct_targets(config: dict, manifest: pd.DataFrame) -> list:
    """
    Use configuration and manifest data to generate the set of comparisons
    required for a full pipeline run.
    """
    res = []
    targets = zip(manifest["experimental_dataset"], manifest["reference_datasets"])
    for target in targets:
        reference_datasets = target[1].split(",")
        for reference_dataset in reference_datasets:
            res.append("results/vcfeval/{}/{}/results.vcf.gz".format(target[0], reference_dataset))
    return res


def map_reference_file(wildcards: Namedlist, config: dict) -> str | AnnotatedString:
    """
    Probe the prefix of a filename to determine which sort of
    remote provider (if any) should be used to acquire a local copy.

    Reference vcfs are pulled from configured blocks in the config yaml.
    """
    ## The intention for this function was to distinguish between S3 file paths and others,
    ## and return wrapped objects related to the remote provider service when appropriate.
    ## There have been periodic issues with the remote provider interface, but it seems
    ## to be working, somewhat inefficiently but very conveniently, for the time being.
    mapped_name = config["reference_datasets"][wildcards.reference]["vcf"]
    if mapped_name.startswith("s3://"):
        return S3.remote(mapped_name)
    elif mapped_name.startswith("https://"):
        return HTTP.remote(mapped_name)
    elif mapped_name.startswith("ftp://"):
        return FTP.remote(mapped_name)
    return mapped_name


def map_experimental_file(wildcards: Namedlist, manifest: pd.DataFrame) -> str | AnnotatedString:
    """
    Probe the prefix of a filename to determine which sort of
    remote provider (if any) should be used to acquire a local copy.

    Experimental vcfs are pulled from columns in the manifest.
    """
    ## The intention for this function was to distinguish between S3 file paths and others,
    ## and return wrapped objects related to the remote provider service when appropriate.
    ## There have been periodic issues with the remote provider interface, but it seems
    ## to be working, somewhat inefficiently but very conveniently, for the time being.
    mapped_name = manifest.loc[wildcards.experimental, "vcf"]
    if mapped_name.startswith("s3://"):
        return S3.remote(mapped_name)
    elif mapped_name.startswith("https://"):
        return HTTP.remote(mapped_name)
    elif mapped_name.startswith("ftp://"):
        return FTP.remote(mapped_name)
    return mapped_name
