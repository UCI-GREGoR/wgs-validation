rule create_sdf:
    """
    Convert a fasta to an sdf format file for rtg tools' particularities
    """
    input:
        lambda wildcards: tc.wrap_remote_file(config["genomes"][wildcards.genome]["fasta"]),
    output:
        "results/{genome}/ref.fasta.sdf",
    benchmark:
        "results/performance_benchmarks/create_sdf/{genome}.tsv"
    conda:
        "../envs/vcfeval.yaml"
    threads: 1
    resources:
        qname="small",
        mem_mb="2000",
    shell:
        "rtg format -f fasta -o {output} {input}"
