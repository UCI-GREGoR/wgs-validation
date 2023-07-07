rule control_validation_report:
    """
    Create an Rmd report about the comparison results
    from either hap.py or vcfeval
    """
    input:
        csv=lambda wildcards: tc.get_benchmarking_output_files(
            wildcards, config, manifest_comparisons
        ),
        r_resources="workflow/scripts/control_validation.R",
    output:
        "results/reports/report_{comparison}_vs_region-{region}.html",
    params:
        manifest_experiment=manifest_experiment,
        manifest_reference=manifest_reference,
        selected_stratifications=config["genomes"][reference_build]["stratification-regions"][
            "region-definitions"
        ],
        comparison_subjects=lambda wildcards: tc.get_happy_comparison_subjects(
            wildcards, manifest_experiment, manifest_comparisons
        ),
        variant_types=lambda wildcards: tc.get_variant_types(
            manifest_comparisons, wildcards.comparison
        ),
    benchmark:
        "results/performance_benchmarks/reports/report_{comparison}_vs_region-{region}.tsv"
    conda:
        "../envs/r.yaml"
    threads: 1
    resources:
        qname="small",
        mem_mb=4000,
    script:
        "../scripts/control_validation.Rmd"
