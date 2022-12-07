rule happy_run:
    """
    Use Illumina's hap.py to compare "gold standard" vcf to experimental calls.

    hap.py is a chunky memory hog. Nevertheless, it does do exactly what you want it
    to, after a fashion.
    """
    input:
        experimental="results/experimentals/{experimental}.vcf.gz",
        reference="results/references/{reference}.vcf.gz",
        bed="results/regions/{region_set}.bed",
        fa="results/{}/ref.fasta".format(reference_build),
    output:
        vcf="results/happy/{experimental}/{reference}/{region_set}/results.vcf.gz",
    benchmark:
        "results/performance_benchmarks/happy/{experimental}/{reference}/{region_set}/results.tsv"
    conda:
        "../envs/happy.yaml"
    threads: 1
    resources:
        qname="small",
        mem_mb="16000",
    shell:
        "hap.py {input.reference} {input.experimental} -f {input.bed} -r {input.fa} -o {params.outprefix}"
