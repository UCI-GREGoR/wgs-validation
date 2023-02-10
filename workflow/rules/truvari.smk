rule tabix_index:
    """
    Index a vcf file. This has minor pattern restrictions to
    avoid conflicts with hap.py
    """
    input:
        "results/{dataset}/{prefix}.vcf.gz",
    output:
        "results/{dataset,references|experimentals}/{prefix}.vcf.gz.tbi",
    conda:
        "../envs/bcftools.yaml"
    threads: 1
    resources:
        mem_mb="2000",
        qname="small",
    shell:
        "tabix -p vcf {input}"


rule sv_within_dataset:
    """
    Filter svs with stratification regions, but don't run svdb to merge anything
    """
    input:
        vcf="results/{dataset_type}/{dataset_name}.vcf.gz",
        stratification_bed=lambda wildcards: get_bedfile_from_name(
            wildcards,
            checkpoints,
            "results/stratification-sets/{}/subsets_for_happy/{{subset_group}}".format(
                reference_build
            ),
        ),
        region_bed="results/confident-regions/{region}.bed",
    output:
        temp(
            "results/{dataset_type}/{region}/{subset_group}/{subset_name}/{dataset_name}.filtered-to-region.vcf.gz"
        ),
    conda:
        "../envs/svdb.yaml"
    threads: 1
    resources:
        mem_mb="8000",
        qname="small",
    shell:
        "bedtools intersect -a {input.stratification_bed} -b {input.region_bed} | "
        "bedtools intersect -a {input.vcf} -b stdin -wa -f 1 -header | bgzip -c > {output}"


rule truvari_run:
    """
    Run truvari based on the documentation at
    https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio/HG002_NA24385_son/NIST_SV_v0.6/README_SV_v0.6.txt
    with certain modifications to reflect changes in the truvari interface.
    """
    input:
        experimental=expand(
            "results/experimentals/{{region}}/{{setgroup}}/{{setname}}/{{experimental}}.{filter_type}.vcf.gz",
            filter_type=sv_experimental_filter_type,
        ),
        experimental_tbi=expand(
            "results/experimentals/{{region}}/{{setgroup}}/{{setname}}/{{experimental}}.{filter_type}.vcf.gz.tbi",
            filter_type=sv_experimental_filter_type,
        ),
        reference=expand(
            "results/references/{{region}}/{{setgroup}}/{{setname}}/{{reference}}.{filter_type}.vcf.gz",
            filter_type=sv_reference_filter_type,
        ),
        reference_tbi=expand(
            "results/references/{{region}}/{{setgroup}}/{{setname}}/{{reference}}.{filter_type}.vcf.gz.tbi",
            filter_type=sv_reference_filter_type,
        ),
        fasta="results/{}/ref.fasta".format(reference_build),
        fai="results/{}/ref.fasta.fai".format(reference_build),
    output:
        temp("results/truvari/{experimental}/{reference}/{region}/{setgroup}/{setname}/fn.vcf"),
        temp("results/truvari/{experimental}/{reference}/{region}/{setgroup}/{setname}/fp.vcf"),
        temp("results/truvari/{experimental}/{reference}/{region}/{setgroup}/{setname}/log.txt"),
        temp("results/truvari/{experimental}/{reference}/{region}/{setgroup}/{setname}/summary.txt"),
        temp("results/truvari/{experimental}/{reference}/{region}/{setgroup}/{setname}/tp-base.vcf"),
        temp("results/truvari/{experimental}/{reference}/{region}/{setgroup}/{setname}/tp-call.vcf"),
    params:
        outdir="results/truvari/{experimental}/{reference}/{region}/{setgroup}/{setname}",
        ref_distance_location="500",
        min_percent_reciprocal_overlap="0.5",
    conda:
        "../envs/truvari.yaml"
    threads: 1
    resources:
        mem_mb="8000",
        qname="small",
    shell:
        "rm -Rf {params.outdir} && "
        "truvari bench -b {input.reference} -c {input.experimental} -f {input.fasta} -o {params.outdir} "
        "--passonly -r {params.ref_distance_location} -O {params.min_percent_reciprocal_overlap}"
