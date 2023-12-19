import os
import pathlib

import pytest

from lib import config_tracking_files as ctf


def test_construct_tracker_filename_str():
    """
    Test that construct_tracker_filename generates
    expected output filename structure when provided
    a string
    """
    results_dir = "whatever"
    analysis_name = "aname"
    tag = "mytag"
    expected = "whatever/aname/mytag.tracking"
    observed = ctf.construct_tracker_filename(results_dir, analysis_name, tag)
    assert expected == observed


def test_construct_tracker_filename_list():
    """
    Test that construct_tracker_filename generates
    expected output filename structure when provided
    a list
    """
    results_dir = "thing1"
    analysis_name = "bname"
    tags = ["tag1", "tag2", "tag3"]
    expected = "thing1/bname/tag1/tag2/tag3.tracking"
    observed = ctf.construct_tracker_filename(results_dir, analysis_name, tags)
    assert expected == observed


def test_update_analysis_tracking_file_none_before_defined_after(tmp_path):
    """
    Test the following circumstance:

    - a tracking file already exists
    - the tracking file is empty, signifying a None setting
    - the new setting is not None
    """
    tracking_file = tmp_path / "nonetest" / "mysetting.tracking"
    pathlib.Path(os.path.dirname(tracking_file)).mkdir(parents=True, exist_ok=True)
    open(tracking_file, "w").close()
    ctf.update_analysis_tracking_file(tmp_path, "nonetest", "newsetting", "mysetting")
    assert pathlib.Path(tmp_path / "nonetest" / "mysetting.tracking").is_file()
    with open(tracking_file, "r") as f:
        lines = f.readlines()
    assert lines == ["newsetting\n"]


def test_update_analysis_tracking_file_none_before_none_after(tmp_path):
    """
    Test the following circumstance:

    - a tracking file already exists
    - the tracking file is empty, signifying a None setting
    - the new setting is None
    """
    tracking_file = tmp_path / "nonetest" / "mysetting.tracking"
    pathlib.Path(os.path.dirname(tracking_file)).mkdir(parents=True, exist_ok=True)
    open(tracking_file, "w").close()
    file_mod_time_start = os.path.getmtime(tracking_file)
    ctf.update_analysis_tracking_file(tmp_path, "nonetest", None, "mysetting")
    assert pathlib.Path(tmp_path / "nonetest" / "mysetting.tracking").is_file()
    assert os.stat(pathlib.Path(tmp_path / "nonetest" / "mysetting.tracking")).st_size == 0
    file_mod_time_end = os.path.getmtime(tracking_file)
    assert file_mod_time_start == file_mod_time_end


def test_update_analysis_tracking_file_defined_before_none_after(tmp_path):
    """
    Test the following circumstance:

    - a tracking file already exists
    - the tracking file is full
    - the new setting is None
    """
    tracking_file = tmp_path / "nonetest" / "mysetting.tracking"
    pathlib.Path(os.path.dirname(tracking_file)).mkdir(parents=True, exist_ok=True)
    with open(tracking_file, "w") as f:
        f.write("mysettingval\n")
    ctf.update_analysis_tracking_file(tmp_path, "nonetest", None, "mysetting")
    assert pathlib.Path(tmp_path / "nonetest" / "mysetting.tracking").is_file()
    assert os.stat(pathlib.Path(tmp_path / "nonetest" / "mysetting.tracking")).st_size == 0


def test_update_analysis_tracking_file_absent_before_none_after(tmp_path):
    """
    Test the following circumstance:

    - a tracking file doesn't exist
    - the new setting is None
    """
    ctf.update_analysis_tracking_file(tmp_path, "nonetest", None, "mysetting")
    assert pathlib.Path(tmp_path / "nonetest" / "mysetting.tracking").is_file()
    assert os.stat(pathlib.Path(tmp_path / "nonetest" / "mysetting.tracking")).st_size == 0


def test_update_analysis_tracking_file_file_dne(tmp_path):
    """
    Test that dynamic updating successfully constructs
    the tracking file and injects content into it
    when the file does not already exist
    """
    analysis_name = "myanalysis"
    output_tag = "mytag"
    current_setting = [3, 2, 1, 4, 5]
    expected_dir = tmp_path / analysis_name
    expected_file = expected_dir / "mytag.tracking"
    expected_contents = [str(setting) for setting in current_setting]
    expected_contents.sort()
    ctf.update_analysis_tracking_file(tmp_path, analysis_name, current_setting, output_tag)

    assert expected_dir.is_dir()
    assert expected_file.is_file()
    with open(expected_file, "r") as f:
        lines = [line.rstrip() for line in f.readlines()]
    assert lines == expected_contents


def test_update_analysis_tracking_file_file_same(tmp_path):
    """
    Test that dynamic updating leaves a file alone
    when the content matches the new settings
    """
    analysis_name = "myanalysis"
    output_tag = "mytag"
    current_setting = [3, 2, 1, 4, 5]
    expected_dir = tmp_path / analysis_name
    expected_dir.mkdir(parents=True, exist_ok=True)
    expected_file = expected_dir / "mytag.tracking"
    expected_contents = [str(setting) for setting in current_setting]
    expected_contents.sort()
    with open(expected_file, "w") as f:
        f.writelines(setting + "\n" for setting in expected_contents)
    file_mod_time_start = os.path.getmtime(expected_file)
    ctf.update_analysis_tracking_file(tmp_path, analysis_name, current_setting, output_tag)
    file_mod_time_end = os.path.getmtime(expected_file)
    with open(expected_file, "r") as f:
        lines = [line.rstrip() for line in f.readlines()]
    assert lines == expected_contents
    assert file_mod_time_start == file_mod_time_end


def test_update_analysis_tracking_file_file_differs(tmp_path):
    """
    Test that dynamic updating successfully replaces
    the tracking file when the file exists but doesn't
    match the current setting
    """
    analysis_name = "myanalysis"
    output_tag = "mytag"
    current_setting = [3, 2, 1, 4, 5]
    expected_dir = tmp_path / analysis_name
    expected_dir.mkdir(parents=True, exist_ok=True)
    expected_file = expected_dir / "mytag.tracking"
    expected_contents = [str(setting) for setting in current_setting]
    expected_contents.sort()
    with open(expected_file, "w") as f:
        f.writelines(setting + "\n" for setting in ["1", "2", "3", "4", "5", "6"])
    ctf.update_analysis_tracking_file(tmp_path, analysis_name, current_setting, output_tag)
    with open(expected_file, "r") as f:
        lines = [line.rstrip() for line in f.readlines()]
    assert lines == expected_contents


def test_update_analysis_tracking_files(config, tmp_path):
    """
    Test that tracking file dispatch function correctly
    iterates across all configuration trackers.

    I think we can assume here that, if the other functions
    are tested, the *contents* of the files don't need
    to be tested, just whether the files exist at all.
    """
    results_prefix = tmp_path / "results"
    ctf.update_analysis_tracking_files(
        config,
        results_prefix,
    )
    filenames = ctf.get_ftp_tracking_files(config, results_prefix)
    for filename in filenames:
        assert pathlib.Path(filename).is_file()


def test_ftp_tracking_files(config):
    """
    Test that the function acquires the appropriate full
    set of tracking files for ftp file downloads.
    """
    results_prefix = "results"
    expected_names = ["name1", "name2"]
    expected = [
        "results/stratification-sets/{}/{}.tracking".format(config["genome-build"], val)
        for val in expected_names
    ]
    expected.sort()
    observed = ctf.get_ftp_tracking_files(config, results_prefix)
    observed.sort()
    assert expected == observed
