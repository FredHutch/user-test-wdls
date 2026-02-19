version 1.0

## Self-Contained RNA-Seq Analysis Pipeline
## This workflow generates its own test data and demonstrates subworkflows and imports

import "quality_control.wdl" as QC
import "alignment.wdl" as Align
import "quantification.wdl" as Quant

workflow RNASeqPipeline {
    input {
        String sample_name = "test_sample"
        Int num_reads = 1000
        Int read_length = 100
        Int quality_threshold = 30
        Int num_threads = 2
    }

    # Generate synthetic test data
    call GenerateTestData {
        input:
            sample_name = sample_name,
            num_reads = num_reads,
            read_length = read_length
    }

    # Call Quality Control subworkflow
    call QC.QualityControl as qc {
        input:
            fastq_r1 = [GenerateTestData.fastq_r1],
            fastq_r2 = [GenerateTestData.fastq_r2],
            quality_threshold = quality_threshold,
            num_threads = num_threads
    }

    # Call Alignment subworkflow with QC outputs
    call Align.AlignmentWorkflow as alignment {
        input:
            trimmed_r1 = qc.trimmed_fastq_r1,
            trimmed_r2 = qc.trimmed_fastq_r2,
            reference_genome = GenerateTestData.reference_genome,
            sample_name = sample_name,
            num_threads = num_threads
    }

    # Call Quantification subworkflow
    call Quant.QuantificationWorkflow as quantification {
        input:
            aligned_bam = alignment.sorted_bam,
            aligned_bam_index = alignment.sorted_bam_index,
            reference_annotation = GenerateTestData.reference_annotation,
            sample_name = sample_name,
            num_threads = num_threads
    }

    output {
        # Test data outputs
        File generated_fastq_r1 = GenerateTestData.fastq_r1
        File generated_fastq_r2 = GenerateTestData.fastq_r2
        File generated_reference = GenerateTestData.reference_genome
        File generated_annotation = GenerateTestData.reference_annotation
        
        # QC outputs
        File qc_report = qc.multiqc_report
        Array[File] trimmed_fastq_r1 = qc.trimmed_fastq_r1
        Array[File] trimmed_fastq_r2 = qc.trimmed_fastq_r2
        
        # Alignment outputs
        File sorted_bam = alignment.sorted_bam
        File sorted_bam_index = alignment.sorted_bam_index
        File alignment_stats = alignment.alignment_stats
        
        # Quantification outputs
        File gene_counts = quantification.gene_counts
        File transcript_counts = quantification.transcript_counts
    }

    meta {
        author: "Self-Contained Workflow Example"
        description: "RNA-Seq pipeline with synthetic data generation demonstrating WDL subworkflows"
    }
}

task GenerateTestData {
    input {
        String sample_name
        Int num_reads
        Int read_length
    }

    command <<<
        set -e
        
        # Generate synthetic reference genome (1000bp with 2 genes)
        cat > reference.fa <<'EOF'
>chr1
ATGCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGAT
CGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGA
TCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCG
ATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATC
GATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGAT
CGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGA
TCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCG
ATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATC
GATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGAT
CGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGA
TCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCG
ATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATC
GATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGAT
CGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGA
TCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCG
ATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATC
GATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGATCGAT
EOF

        # Generate GTF annotation
        cat > genes.gtf <<'EOF'
chr1	test	gene	1	300	.	+	.	gene_id "GENE001"; gene_name "TestGene1";
chr1	test	transcript	1	300	.	+	.	gene_id "GENE001"; transcript_id "TRANS001";
chr1	test	exon	1	150	.	+	.	gene_id "GENE001"; transcript_id "TRANS001"; exon_number "1";
chr1	test	exon	200	300	.	+	.	gene_id "GENE001"; transcript_id "TRANS001"; exon_number "2";
chr1	test	gene	400	700	.	+	.	gene_id "GENE002"; gene_name "TestGene2";
chr1	test	transcript	400	700	.	+	.	gene_id "GENE002"; transcript_id "TRANS002";
chr1	test	exon	400	550	.	+	.	gene_id "GENE002"; transcript_id "TRANS002"; exon_number "1";
chr1	test	exon	600	700	.	+	.	gene_id "GENE002"; transcript_id "TRANS002"; exon_number "2";
EOF

        # Generate synthetic paired-end FASTQ files
        python3 <<'PYTHON_SCRIPT'
import random
import gzip

def generate_quality_string(length):
    """Generate random quality scores (Phred+33)"""
    return ''.join(chr(random.randint(33, 73)) for _ in range(length))

def generate_read(length):
    """Generate random DNA sequence"""
    bases = ['A', 'T', 'G', 'C']
    return ''.join(random.choice(bases) for _ in range(length))

num_reads = ~{num_reads}
read_length = ~{read_length}
sample_name = "~{sample_name}"

# Generate R1
with gzip.open(f'{sample_name}_R1.fastq.gz', 'wt') as f1:
    for i in range(num_reads):
        f1.write(f'@READ_{i+1}/1\n')
        f1.write(generate_read(read_length) + '\n')
        f1.write('+\n')
        f1.write(generate_quality_string(read_length) + '\n')

# Generate R2
with gzip.open(f'{sample_name}_R2.fastq.gz', 'wt') as f2:
    for i in range(num_reads):
        f2.write(f'@READ_{i+1}/2\n')
        f2.write(generate_read(read_length) + '\n')
        f2.write('+\n')
        f2.write(generate_quality_string(read_length) + '\n')

print(f"Generated {num_reads} paired-end reads")
PYTHON_SCRIPT

        echo "Test data generation complete"
    >>>

    output {
        File fastq_r1 = "~{sample_name}_R1.fastq.gz"
        File fastq_r2 = "~{sample_name}_R2.fastq.gz"
        File reference_genome = "reference.fa"
        File reference_annotation = "genes.gtf"
    }

    runtime {
        docker: "python:3.9-slim"
        cpu: 1
        memory: "2 GB"
    }
}
