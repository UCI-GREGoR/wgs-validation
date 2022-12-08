rule control_validation_report:
    """
    Create an Rmd report about the comparison results
    from either hap.py or vcfeval
    """
    input:
        csv=lambda wildcards: tc.get_happy_output_files(wildcards, manifest_comparisons),
        r_resources="workflow/scripts/control_validation.R",
    output:
        "results/reports/control_validation_{comparison}.html",
    params:
        manifest_experiment=manifest_experiment,
        manifest_reference=manifest_reference,
    benchmark:
        "results/performance_benchmarks/reports/control_validation_{comparison}.tsv"
    conda:
        "../envs/r.yaml"
    threads: 1
    resources:
        qname="small",
        mem_mb="4000",
    script:
        "../scripts/control_validation.Rmd"
