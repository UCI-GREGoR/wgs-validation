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
        selected_stratifications=lambda wildcards: tc.flatten_region_definitions(
            config, region_label_df, reference_build
        ),
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
    threads: config_resources["r"]["threads"]
    resources:
        slurm_partition=rc.select_partition(
            config_resources["r"]["partition"], config_resources["partitions"]
        ),
        mem_mb=config_resources["r"]["memory"],
    script:
        "../scripts/control_validation.Rmd"
