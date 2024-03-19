import os
import pathlib


def construct_tracker_filename(results_prefix: str, analysis_name: str, output_tag) -> str:
    """
    Handle construction of tracker filenames in a centralized manner,
    to attempt to prevent desync.
    """
    tag = output_tag
    if type(tag) != list:
        tag = [tag]
    return "{}/{}/{}.tracking".format(results_prefix, analysis_name, "/".join(tag))


def update_analysis_tracking_file(
    results_prefix: str, analysis_name: str, current_setting, output_tag: str
) -> None:
    """
    Conditionally update tracking files for configuration
    settings, only if they have changed from the most recent
    setting.

    The hope is that by updating these files intelligently,
    the pipeline can avoid some reruns that are particularly
    computationally costly.
    """
    tracker_filename = construct_tracker_filename(results_prefix, analysis_name, output_tag)
    current_setting_for_comparison = current_setting
    if current_setting is not None:
        if type(current_setting) == int:
            current_setting_for_comparison = [str(current_setting)]
        elif type(current_setting) == str:
            current_setting_for_comparison = [current_setting]
        elif type(current_setting) == float:
            current_setting_for_comparison = [str(current_setting)]
        elif type(current_setting) == bool:
            current_setting_for_comparison = [str(current_setting)]
        current_setting_for_comparison = [
            str(setting) for setting in current_setting_for_comparison
        ]
        current_setting_for_comparison.sort()
    if pathlib.Path(tracker_filename).is_file():
        if current_setting is None and os.stat(tracker_filename).st_size == 0:
            return
        with open(tracker_filename, "r") as f:
            lines = [line.rstrip() for line in f.readlines()]
            if lines == current_setting_for_comparison:
                return
    pathlib.Path(os.path.dirname(tracker_filename)).mkdir(parents=True, exist_ok=True)

    with open(tracker_filename, "w") as f:
        if current_setting is not None:
            f.writelines(setting + "\n" for setting in current_setting_for_comparison)


def update_analysis_tracking_files(
    config: dict,
    results_prefix: str,
) -> None:
    """
    Dispatch update tasks for all loaded configuration files.

    The idea here is that we want to enable datasets and intermediates
    when their pertinent configuration settings are changed, but
    not when superfluous timestamp changes cause snakemake to think
    that something interesting has happened but in fact it hasn't.
    """
    ## configuration data for ftp pulls of stratification sets
    stratification_sets = [
        x["name"]
        for x in filter(
            lambda z: z["name"] != "*",
            config["genomes"][config["genome-build"]]["stratification-regions"][
                "region-inclusions"
            ],
        )
    ]
    for stratification_set in stratification_sets:
        update_analysis_tracking_file(
            results_prefix,
            "stratification-sets/{}".format(config["genome-build"]),
            "in-use",
            stratification_set,
        )


def get_ftp_tracking_files(config, results_prefix) -> list:
    """
    Get the currently configured set of tracking files for
    stratification sets.
    """
    stratification_sets = [
        x["name"]
        for x in filter(
            lambda z: z["name"] != "*",
            config["genomes"][config["genome-build"]]["stratification-regions"][
                "region-inclusions"
            ],
        )
    ]
    return [
        construct_tracker_filename(
            results_prefix, "stratification-sets/{}".format(config["genome-build"]), x
        )
        for x in stratification_sets
    ]
