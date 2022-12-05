rule vcfeval_run:
    """
    Eventually, this will handle dispatch of vcfeval; but for the time being,
    this will just pass through to earlier parts of the DAG.
    """
    input:
        experimental="results/experimentals/{experimental}.vcf.gz",
        reference="results/references/{reference}.vcf.gz",
    output:
        vcf="results/vcfeval/{experimental}/{reference}/results.vcf.gz",
    threads: 1
    resources:
        qname="small",
        mem_mb="1000",
    shell:
        "touch {output}"
