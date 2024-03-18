localrules:
    add_region_name,
    combine_results,
    happy_create_stratification_subset,


checkpoint happy_create_stratification_subset:
    """
    Create a file containing a subset of the input stratification files,
    to address the fact that hap.py is a giant resource hog.
    """
    input:
        "results/stratification-sets/{genome_build}.stratification_regions.tsv",
        lambda wildcards: tc.get_required_stratifications(wildcards, config, checkpoints),
    output:
        "results/stratification-sets/{genome_build}/subsets_for_happy/{stratification_set}/stratification_subset.tsv",
    params:
        contents=lambda wildcards: tc.get_happy_stratification_by_index(
            wildcards, config, checkpoints
        ),
    threads: config_resources["default"]["threads"]
    shell:
        "echo -e \"{params.contents}\" | sed 's/\\r//g' > {output}"


rule happy_run:
    """
    Use Illumina's hap.py to compare "gold standard" vcf to experimental calls.

    hap.py is a chunky memory hog. Nevertheless, it does do exactly what you want it
    to, after a fashion.

    Eventually, most of these output files will be temp() or merged into single outputs.
    """
    input:
        experimental="results/experimentals/{experimental}.vcf.gz",
        reference="results/references/{reference}.vcf.gz",
        fa="results/{}/ref.fasta".format(reference_build),
        fai="results/{}/ref.fasta.fai".format(reference_build),
        sdf="results/{}/ref.fasta.sdf".format(reference_build),
        stratification="results/stratification-sets/{}/subsets_for_happy/{{stratification_set}}/stratification_subset.tsv".format(
            reference_build
        ),
        stratification_files=lambda wildcards: tc.get_required_stratifications(
            wildcards, config, checkpoints
        ),
        bed="results/confident-regions/{region}.bed",
        rtg_wrapper="workflow/scripts/rtg.bash",
    output:
        expand(
            "results/happy/{{experimental}}/{{reference}}/{{region,[^/]+}}/{{stratification_set,[^/]+}}/results.{suffix}",
            suffix=[
                "extended.csv",
                "metrics.json.gz",
                "roc.all.csv.gz",
                "roc.Locations.INDEL.csv.gz",
                "roc.Locations.INDEL.PASS.csv.gz",
                "roc.Locations.SNP.csv.gz",
                "roc.Locations.SNP.PASS.csv.gz",
                "runinfo.json",
                "summary.csv",
                "vcf.gz",
                "vcf.gz.tbi",
            ],
        ),
    params:
        outprefix="results/happy/{experimental}/{reference}/{region}/{stratification_set}/results",
        tmpdir="temp/happy/{experimental}/{reference}/{region}/{stratification_set}",
    benchmark:
        "results/performance_benchmarks/happy_run/{experimental}/{reference}/{region}/{stratification_set}/results.tsv"
    conda:
        "../envs/happy.yaml"
    threads: config_resources["happy"]["threads"]
    resources:
        slurm_partition=rc.select_partition(
            config_resources["happy"]["partition"], config_resources["partitions"]
        ),
        mem_mb=config_resources["happy"]["memory"],
        tmpdir=lambda wildcards: "temp/happy/{}/{}/{}/{}".format(
            wildcards.experimental,
            wildcards.reference,
            wildcards.region,
            wildcards.stratification_set,
        ),
    shell:
        "mkdir -p {params.tmpdir} && "
        "RTG_MEM=12G HGREF={input.fa} hap.py {input.reference} {input.experimental} -f {input.bed} -o {params.outprefix} "
        "--stratification {input.stratification} "
        "-V --engine=vcfeval --engine-vcfeval-path={input.rtg_wrapper} --engine-vcfeval-template={input.sdf} "
        "--threads {threads} --scratch-prefix {params.tmpdir}"


rule add_region_name:
    """
    To prepare for merging files from separate regions, prefix the lines
    with the name of the region.
    """
    input:
        "results/{comparison_type}/{experimental}/{reference}/{region}/{stratification_set}/results.extended.csv",
    output:
        temp(
            "results/{comparison_type,[^/]+}/{experimental}/{reference}/{region,[^/]+}/{stratification_set,[^/]+}/results.extended.annotated.csv"
        ),
    shell:
        "cat {input} | "
        "awk -v ex={wildcards.experimental} -v ref={wildcards.reference} -v reg={wildcards.region} "
        '\'NR == 1 {{print "Experimental,Reference,Region,"$0}} ; NR > 1 {{print ex","ref","reg","$0}}\' > {output}'


rule combine_results:
    """
    Combine annotated summary results from Illumina's hap.py utility run against different sets of stratification regions.
    """
    input:
        lambda wildcards: expand(
            "results/{{comparison_type}}/{{experimental}}/{{reference}}/{{region}}/{stratification_set}/results.extended.annotated.csv",
            stratification_set=tc.get_happy_stratification_set_indices(
                wildcards, config, checkpoints
            ),
        ),
    output:
        "results/{comparison_type,[^/]+}/{experimental,[^/]+}/{reference,[^/]+}/{region,[^/]+}/results.extended.csv",
    benchmark:
        "results/performance_benchmarks/{comparison_type}_combine_results/{experimental}/{reference}/{region}/results.tsv"
    shell:
        "cat {input} | awk 'NR == 1 || ! /^Experimental,Reference,Region,/' > {output}"
