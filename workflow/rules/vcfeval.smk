rule vcfeval_run:
    """
    Eventually, this will handle dispatch of vcfeval; but for the time being,
    this will just pass through to earlier parts of the DAG.
    """
    input:
        experimental="results/experimentals/{experimental}.vcf.gz",
        reference="results/references/{reference}.vcf.gz",
        sdf="results/{}/ref.fasta.sdf".format(reference_build),
    output:
        vcf="results/vcfeval/{experimental}/{reference}/results.vcf.gz",
    conda:
        "../envs/vcfeval.yaml"
    threads: config_resources["rtg-vcfeval"]["threads"]
    resources:
        slurm_partition=rc.select_partition(
            config_resources["rtg-vcfeval"]["partition"], config_resources["partitions"]
        ),
    shell:
        "rtg vcfeval --baseline={input.reference} --calls={input.experimental} --template={input.sdf} "
        "--output-mode=annotate --output={output} --Xtwo-pass=False --ref-overlap"


## there is also a --bed={} argument for restricting evaluation regions.
## however, the existing runs all point to some dude's home directory.
## :(
