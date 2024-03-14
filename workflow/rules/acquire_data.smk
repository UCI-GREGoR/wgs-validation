rule download_reference_data:
    """
    Using wildcards and configuration data, get reference vcf.

    This is refactored to old garbage bash style, as the snakemake FTP remote
    has serious timeout problems.
    """
    output:
        "results/references/{reference,[^/]+}.vcf.gz",
    params:
        lambda wildcards: tc.map_reference_file(wildcards, manifest_reference),
    conda:
        "../envs/awscli.yaml"
    threads: config_resources["default"]["threads"]
    resources:
        slurm_partition=rc.select_partition(
            config_resources["default"]["partition"], config_resources["partitions"]
        ),
        mem_mb=config_resources["default"]["memory"],
    shell:
        "if [[ {params} = s3://* ]] ; then "
        "aws s3 cp {input} {output} ; "
        "elif [[ {params} = ftp://* ]] || [[ {params} = https://* ]] || [[ {params} = http://* ]] ; then "
        "wget -O {output} {params} ; "
        "else cp {params} {output} ; fi"


use rule download_reference_data as download_experimental_data with:
    output:
        "results/experimentals/{experimental,[^/]+}.vcf.gz",
    params:
        lambda wildcards: tc.map_experimental_file(wildcards, manifest_experiment),
