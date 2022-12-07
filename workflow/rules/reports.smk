rule control_validation_report:
    """
    Create an Rmd report about the comparison results
    from either hap.py or vcfeval
    """
    input:
        lambda wildcards: tc.get_happy_output_files(config, manifest_comparisons),
    output:
        "results/reports/control_validation.html",
    params:
        r_resources="../scripts/control_validation.R",
    benchmark:
        "results/performance_benchmarks/reports/control_validation.html"
    conda:
        "../envs/r.yaml"
    threads: 1
    resources:
        qname="small",
        mem_mb="4000",
    script:
        "../scripts/control_validation.Rmd"
