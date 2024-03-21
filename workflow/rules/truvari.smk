rule tabix_index:
    """
    Index a vcf file. This has minor pattern restrictions to
    avoid conflicts with hap.py
    """
    input:
        "results/{dataset}/{prefix}.vcf.gz",
    output:
        temp("results/{dataset,references|experimentals}/{prefix}.vcf.gz.tbi"),
    conda:
        "../envs/bcftools.yaml"
    threads: config_resources["bcftools"]["threads"]
    resources:
        slurm_partition=rc.select_partition(
            config_resources["bcftools"]["partition"], config_resources["partitions"]
        ),
        mem_mb=config_resources["bcftools"]["memory"],
    shell:
        "tabix -p vcf {input}"


rule sv_within_dataset:
    """
    Filter svs with stratification regions, but don't run svdb to merge anything
    """
    input:
        vcf="results/{dataset_type}/{dataset_name}.vcf.gz",
        stratification_bed=lambda wildcards: tc.get_bedfile_from_name(
            wildcards,
            checkpoints,
            reference_build,
        ),
        region_bed="results/confident-regions/{region}.bed",
    output:
        temp(
            "results/{dataset_type}/{region}/{subset_group}/{subset_name}/{dataset_name}.filtered-to-region.vcf.gz"
        ),
    conda:
        "../envs/svdb.yaml"
    threads: config_resources["svdb"]["threads"]
    resources:
        slurm_partition=rc.select_partition(
            config_resources["svdb"]["partition"], config_resources["partitions"]
        ),
        mem_mb=config_resources["svdb"]["memory"],
    shell:
        "bedtools intersect -a {input.stratification_bed} -b {input.region_bed} | "
        "bedtools intersect -a {input.vcf} -b stdin -wa -f 1 -header | bgzip -c > {output}"


rule truvari_bench:
    """
    Run truvari benchmarking based on the documentation at
    https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio/HG002_NA24385_son/NIST_SV_v0.6/README_SV_v0.6.txt
    with certain modifications to reflect changes in the truvari interface.
    """
    input:
        experimental=expand(
            "results/experimentals/{{region}}/{{subset_group}}/{{subset_name}}/{{experimental}}.{filter_type}.vcf.gz",
            filter_type=sv_experimental_filter_type,
        ),
        experimental_tbi=expand(
            "results/experimentals/{{region}}/{{subset_group}}/{{subset_name}}/{{experimental}}.{filter_type}.vcf.gz.tbi",
            filter_type=sv_experimental_filter_type,
        ),
        reference=expand(
            "results/references/{{region}}/{{subset_group}}/{{subset_name}}/{{reference}}.{filter_type}.vcf.gz",
            filter_type=sv_reference_filter_type,
        ),
        reference_tbi=expand(
            "results/references/{{region}}/{{subset_group}}/{{subset_name}}/{{reference}}.{filter_type}.vcf.gz.tbi",
            filter_type=sv_reference_filter_type,
        ),
        fasta="results/{}/ref.fasta".format(reference_build),
        fai="results/{}/ref.fasta.fai".format(reference_build),
        includebed=lambda wildcards: tc.get_bedfile_from_name(
            wildcards,
            checkpoints,
            reference_build,
        ),
    output:
        temp(
            "results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/fn.vcf.gz"
        ),
        temp(
            "results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/fn.vcf.gz.tbi"
        ),
        temp(
            "results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/fp.vcf.gz"
        ),
        temp(
            "results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/fp.vcf.gz.tbi"
        ),
        temp(
            "results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/log.txt"
        ),
        temp(
            "results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/params.json"
        ),
        temp(
            "results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/summary.json"
        ),
        temp(
            "results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/tp-base.vcf.gz"
        ),
        temp(
            "results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/tp-base.vcf.gz.tbi"
        ),
        temp(
            "results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/tp-comp.vcf.gz"
        ),
        temp(
            "results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/tp-comp.vcf.gz.tbi"
        ),
    params:
        outdir="results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}",
        ref_distance_location="500",
        min_percent_reciprocal_overlap="0.5",
        min_sequence_overlap="0",
    conda:
        "../envs/truvari.yaml"
    threads: config_resources["truvari"]["threads"]
    resources:
        slurm_partition=rc.select_partition(
            config_resources["truvari"]["partition"], config_resources["partitions"]
        ),
        mem_mb=config_resources["truvari"]["memory"],
    shell:
        "rm -Rf {params.outdir} && "
        "truvari bench -b {input.reference} -c {input.experimental} -f {input.fasta} -o {params.outdir} "
        "--passonly -r {params.ref_distance_location} -O {params.min_percent_reciprocal_overlap} "
        "--pctseq {params.min_sequence_overlap} --dup-to-ins --includebed {input.includebed}"


rule truvari_refine:
    """
    Refine existing truvari benchmarking based on the documentation at https://github.com/ACEnglish/truvari/wiki/refine.
    The `refine` functionality is only present in pre-4.0, and as such I'm trying out their develop branch using
    a local installation of the package. If this seems to have desirable functionality, I will consider what action
    to take.
    """
    input:
        fn="results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/fn.vcf.gz",
        fn_tbi="results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/fn.vcf.gz.tbi",
        fp="results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/fp.vcf.gz",
        fp_tbi="results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/fp.vcf.gz.tbi",
        logfile="results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/log.txt",
        params_json="results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/params.json",
        summary="results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/summary.json",
        tp_base="results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/tp-base.vcf.gz",
        tp_base_tbi="results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/tp-base.vcf.gz.tbi",
        tp_comp="results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/tp-comp.vcf.gz",
        tp_comp_tbi="results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/tp-comp.vcf.gz.tbi",
    output:
        temp(
            "results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/refine.variant_summary.json"
        ),
        temp(
            "results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/refine.regions.txt"
        ),
        temp(
            "results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}/refine.region_summary.json"
        ),
    params:
        outdir="results/truvari/{experimental}/{reference}/{region}/{subset_group}/{subset_name}",
    conda:
        "../envs/truvari.yaml"
    threads: config_resources["truvari"]["threads"]
    resources:
        slurm_partition=rc.select_partition(
            config_resources["truvari"]["partition"], config_resources["partitions"]
        ),
        mem_mb=config_resources["truvari"]["memory"],
    shell:
        "rm -Rf {params.outdir}/phab && "
        "truvari refine {params.outdir}"
