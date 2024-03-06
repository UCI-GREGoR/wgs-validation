import os
import re
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


def get_benchmarking_output_files(
    wildcards,
    config,
    manifest_comparisons: pd.DataFrame,
) -> list:
    """
    Use configuration and manifest data to generate the set of comparisons
    required for a full complement of hap.py, truvari, etc. runs.

    Comparisons are specified as rows in manifest_comparisons. The entries in those
    two columns *should* exist as indices in the corresponding other manifests.
    """
    res = []
    for reference, experimental, comparison_type, report in zip(
        manifest_comparisons["reference_dataset"],
        manifest_comparisons["experimental_dataset"],
        manifest_comparisons["comparison_type"],
        manifest_comparisons["report"],
    ):
        if wildcards.comparison in report.split(","):
            res.append(
                "results/{}/{}/{}/{}/results.extended.csv".format(
                    "happy" if comparison_type == "SNV" else config["sv-toolname"],
                    experimental,
                    reference,
                    wildcards.region,
                )
            )
    return res


def get_happy_comparison_subjects(
    wildcards,
    manifest_experiment: pd.DataFrame,
    manifest_comparisons: pd.DataFrame,
) -> list:
    """
    Use configuration and manifest data to generate the set of subjects
    included in a specific comparison set.
    """
    res = []
    for experimental, report in zip(
        manifest_comparisons["experimental_dataset"],
        manifest_comparisons["report"],
    ):
        if wildcards.comparison in report.split(","):
            res.extend(
                manifest_experiment.loc[
                    manifest_experiment["experimental_dataset"] == experimental, "replicate"
                ].to_list()
            )
    return list(set(res))


def get_variant_types(manifest_comparisons: pd.DataFrame, comparison: str) -> list:
    """
    Determine the variant types that should be queried from hap.py output files
    based on requested comparison type
    """
    res = []
    for report, comparison_type in zip(
        manifest_comparisons["report"], manifest_comparisons["comparison_type"]
    ):
        if comparison in report.split(","):
            if comparison_type == "SV":
                res.append("SV")
            elif comparison_type == "SNV":
                res.append("SNP")
                res.append("INDEL")
            else:
                raise ValueError('Unrecognized comparison type: "{}"'.format(comparison_type))
    return list(set(res))


def construct_targets(
    config, manifest_experiment: pd.DataFrame, manifest_comparisons: pd.DataFrame
) -> list:
    """
    Use comparison manifest data to generate the set of comparisons
    required for a full pipeline run.
    """
    comparisons = [x.split(",") for x in manifest_comparisons["report"]]
    comparisons = [x for y in comparisons for x in y]
    res = []
    for comparison in comparisons:
        regions = []
        confident_regions = config["genomes"][config["genome-build"]]["confident-regions"]
        for region in confident_regions:
            if "inclusion" in confident_regions[region]:
                target_subjects = []
                for experimental, report in zip(
                    manifest_comparisons["experimental_dataset"], manifest_comparisons["report"]
                ):
                    if comparison in report.split(","):
                        target_subjects.extend(
                            manifest_experiment.loc[
                                manifest_experiment["experimental_dataset"] == experimental,
                                "replicate",
                            ].to_list()
                        )
                target_subjects = list(set(target_subjects))
                target_pattern = re.compile(confident_regions[region]["inclusion"])
                target_subjects = list(filter(target_pattern.match, target_subjects))
                if len(target_subjects) > 0:
                    regions.append(region)
            else:
                regions.append(region)
        res.extend(
            expand(
                "results/reports/report_{comparison}_vs_region-{region}.html",
                comparison=comparison,
                region=regions,
            )
        )
    res = list(set(res))
    res.sort()
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
    return mapped_name


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
    return mapped_name


def get_happy_stratification_by_index(wildcards, config, checkpoints):
    """
    Given the index of a stratification region in its original annotation file,
    return the list of implicated entries.
    """
    beds_per_set = config["happy-bedfiles-per-stratification"]
    stratification_sets = [
        x["name"]
        for x in filter(
            lambda z: z["name"] != "*",
            config["genomes"][config["genome-build"]]["stratification-regions"][
                "region-definitions"
            ],
        )
    ]
    regions = pd.read_table(
        checkpoints.get_stratification_files.get(genome_build=config["genome-build"]).output[0],
        header=None,
        names=["key", "path"],
    ).set_index("key", drop=False)
    lines = [
        "{}\\tresults/stratification-sets/{}/{}".format(x, config["genome-build"], y)
        for x, y in zip(
            regions.loc[stratification_sets, "key"], regions.loc[stratification_sets, "path"]
        )
    ]
    lines = [
        lines[i]
        for i in range(
            int(wildcards.stratification_set) * beds_per_set,
            min((int(wildcards.stratification_set) + 1) * beds_per_set, len(lines)),
        )
    ]
    return "\\n".join(lines)


def get_happy_stratification_set_indices(wildcards, config, checkpoints):
    """
    Given the checkpoint output of stratification region download, get a list of indices that can
    be used as intermediate names for the region files during DAG construction.
    """
    beds_per_set = config["happy-bedfiles-per-stratification"]
    stratification_sets = [
        x["name"]
        for x in filter(
            lambda z: z["name"] != "*",
            config["genomes"][config["genome-build"]]["stratification-regions"][
                "region-definitions"
            ],
        )
    ]
    regions = pd.read_table(
        checkpoints.get_stratification_files.get(genome_build=config["genome-build"]).output[0],
        header=None,
        names=["key", "path"],
    ).set_index("key", drop=False)
    regions = regions.loc[stratification_sets]
    return [x for x in range(ceil(len(regions) / beds_per_set))]


def flatten_region_definitions(config: dict, reference_build: str) -> list:
    """
    Snakemake flattens certain types of configuration dict structures into
    simple string lists when passing the structures into scripts. This flattening
    is awkward but functional. However, in order to use the flattened list,
    which evidently strips the keys from the dict, one must assume the fixed
    order of the values in the config. The yaml package seems to preserve
    the order of the keys as observed in the config file, which creates the
    possibility that a user might provide a shuffled but valid specification
    of a region and then break the logic that assumes the key order incorrectly.

    As such, we need to flatten it manually, enforcing order.
    """
    region_definitions = config["genomes"][reference_build]["stratification-regions"][
        "region-definitions"
    ]
    res = []
    for region_definition in region_definitions:
        res.extend(
            [region_definition["name"], region_definition["label"], region_definition["inclusion"]]
        )
    return res
