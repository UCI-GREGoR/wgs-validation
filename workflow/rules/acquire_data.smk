rule download_reference_data:
    """
    Using wildcards and configuration data, get reference vcf
    """
    input:
        lambda wildcards: tc.map_reference_file(wildcards, config),
    output:
        "results/references/{reference}.vcf.gz",
    threads: 1
    resources:
        qname="small",
        mem_mb="1000",
    shell:
        "cp {input} {output}"


use rule download_reference_data as download_experimental_data with:
    input:
        lambda wildcards: tc.map_experimental_file(wildcards, manifest),
    output:
        "results/experimentals/{experimental}.vcf.gz",
