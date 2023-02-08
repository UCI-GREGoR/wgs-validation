rule svanalyzer_run:
    """
    Use svanalyzer to emit benchmarking metrics for SVs. Tool is included due to reference in
    https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio/HG002_NA24385_son/NIST_SV_v0.6/README_SV_v0.6.txt

    The reference to svanalyzer in the NIST documents does not say that they actually ran the tool _per se_,
    but just that they think it's a candidate tool. I don't know if this just means Justin Zook saw it at a poster
    presentation or what.

    Exposed parameters are (minimally) described at https://github.com/nhansen/SVanalyzer/blob/master/docs/svbenchmark.rst
    """
    input:
        experimental="results/experimentals/{region}/{setgroup}/{setname}/{experimental}.within-svdb.vcf.gz",
        experimental_tbi="results/experimentals/{region}/{setgroup}/{setname}/{experimental}.within-svdb.vcf.gz.tbi",
        reference="results/references/{region}/{setgroup}/{setname}/{reference}.within-svdb.vcf.gz",
        reference_tbi="results/references/{region}/{setgroup}/{setname}/{reference}.within-svdb.vcf.gz.tbi",
        fasta="results/{}/ref.fasta".format(reference_build),
        fai="results/{}/ref.fasta.fai".format(reference_build),
    output:
        temp(
            "results/svanalyzer/{experimental}/{reference}/{region}/{setgroup}/{setname}.distances"
        ),
        temp(
            "results/svanalyzer/{experimental}/{reference}/{region}/{setgroup}/{setname}.falsenegatives.vcf"
        ),
        temp(
            "results/svanalyzer/{experimental}/{reference}/{region}/{setgroup}/{setname}.falsepositives.vcf"
        ),
        temp("results/svanalyzer/{experimental}/{reference}/{region}/{setgroup}/{setname}.log"),
        temp("results/svanalyzer/{experimental}/{reference}/{region}/{setgroup}/{setname}.report"),
    params:
        outdir="results/svanalyzer/{experimental}/{reference}/{region}/{setgroup}/{setname}",
        maxdist="100000",
        normshift="0.2",
        normsizediff="0.2",
        normdist="0.2",
        minsize="0",
    conda:
        "../envs/svanalyzer.yaml"
    threads: 1
    resources:
        mem_mb="8000",
        qname="small",
    shell:
        "svanalyzer benchmark --ref {input.fasta} --test {input.experimental} --truth {input.reference} "
        "--prefix {params.outdir} --maxdist {params.maxdist} --normshift {params.normshift} "
        "--normsizediff {params.normsizediff} --normdist {params.normdist} --minsize {params.minsize}"
