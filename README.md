# Sentieon Secondary Analysis

This repository contains workflows for genomic analysis using Sentieon's genomics tools, supporting both short-read and long-read sequencing data. For detailed information about Sentieon's tools and algorithms, please refer to the [Sentieon Manual](https://support.sentieon.com/manual/).

## Prerequisites

Run the [**Download Genomic Reference Resources**](download.task.yaml) task to download and prepare the required local reference sequence and model files. These resources must be available on your system before running any of the workflows.

For long-read workflows, ensure the **Sentieon Long Read Models** option is enabled when running the Download Genomic Reference Resources task to download the required model bundles for HiFi and ONT sequencing technologies.

Before downloading, use [Workspace Settings](./manage/settings) to specify the target location with the `RESOURCE_PATH` variable.

## Overview

This repository contains four comprehensive workflows for different analysis scenarios:

1. **Targeted Germline Small-Variant Calling** - Short-read germline analysis for panels and exomes
2. **Long-Read Germline Variant Calling** - Long-read germline analysis for PacBio HiFi and ONT data
3. **Somatic Tumor/Tumor-Normal Calling** - Short-read somatic analysis with tumor-normal pairing
4. **Comprehensive Whole-Genome Analysis with PGx** - Complete WGS workflow including pharmacogenomics

## Workflows

### 1. Targeted Germline Small-Variant Calling

The Targeted Germline Small-Variant Calling workflow performs alignment and variant calling for short-read germline samples, optimized for targeted sequencing (panels and exomes).

#### Workflow Stages

1. **Prepare Directories**: Sets up output directory structure
2. **Alignment with BWA-MEM**: Aligns FASTQ files to a reference genome
3. **Variant Calling with DNAscope**: Calls variants from aligned BAM files

#### Key Features

- Supports both single-end and paired-end reads
- Automatic sample detection from FASTQ file naming patterns (`*_*.fastq.gz` or `*_*.fq.gz`)
- Optional deduplication and alignment metrics
- Configurable machine learning models for platform-specific optimization
- Optional gVCF output for joint genotyping workflows
- Support for multiple sequencing platforms (Illumina, Element Biosciences, MGI, Salus, Ultima Genomics)

#### Workflow Parameters

- **Input Folder**: Directory containing FASTQ files
- **Output Folder**: Directory where results will be stored
- **Machine Learning Model**: Platform-specific model for optimization (default: None)
- **Reference File**: FASTA file for alignment and variant calling (defaults to workspace reference)
- **Output GVCF**: Generate gVCF format for joint genotyping (default: false)

#### Input Requirements

- **File Format**: FASTQ files (`.fastq.gz` or `.fq.gz`)
- **Naming Convention**: Files should follow the pattern `{sample_name}_*.fastq.gz` where the sample name is extracted from the filename up to the first underscore
- **Read Types**: Supports both single-end and paired-end reads (auto-detected)

#### Output Files

- **Aligned BAM**: `{sample_name}.bam` - Aligned reads ready for variant calling
- **VCF**: `{sample_name}.vcf.gz` - Called variants in standard VCF format
- **gVCF**: `{sample_name}.g.vcf.gz` - Genomic VCF format (if enabled)
- **Metrics**: Alignment and quality metrics files

---

### 2. Long-Read Germline Variant Calling

The Long-Read Germline Variant Calling workflow performs alignment and variant calling for long-read sequencing data, supporting both PacBio HiFi and Oxford Nanopore Technologies (ONT) platforms.

#### Workflow Stages

1. **Prepare Directories**: Sets up output directory structure from batch TSV file
2. **Alignment with Minimap2**: Aligns FASTQ or uBAM files to a reference genome
3. **Merge Minimap2 BAMs**: Merges multiple alignment outputs per sample
4. **Variant Calling with Sentieon CLI**: Calls variants using long-read optimized algorithms
5. **Create VarSeq Project** (optional): Creates a VarSeq project from results

#### Key Features

- **Batch File Support**: Processes multiple samples from a TSV batch file
- **Failed Target Handling**: Automatically skips alignment for failed target regions
- **Automatic BAM Merging**: Merges multiple alignment outputs per sample before variant calling
- **Unique Filename Handling**: Prevents overwriting when multiple input files map to the same sample
- **Comprehensive Variant Calling**: Supports both small variants and structural variants
- **Sample Catalog Integration**: Automatically updates sample catalog with merged BAM paths
- **Technology Support**: Optimized for both HiFi and ONT sequencing platforms

#### Batch File Format

The workflow requires a TSV file with the following columns:
- `alignment_file`: Path to the FASTQ or uBAM file
- `sample_id`: Sample identifier
- `failed_target`: Boolean indicating if this is a failed target (true/false)

Example:
```
alignment_file	sample_id	failed_target
devdata/sample1/file1.fastq	HG001	false
devdata/sample1/file2.fastq	HG001	false
devdata/sample2/file1.fastq	HG002	false
```

#### Workflow Parameters

- **Batch TSV File**: TSV file containing alignment files and sample information
- **Output Folder**: Directory where results will be stored
- **Sequencing Technology**: Platform used for sequencing (HiFi or ONT, default: HiFi)
- **Reference File**: FASTA file for alignment and variant calling (defaults to workspace reference)
- **Sentieon Models Base Path**: Optional path to Sentieon model bundles
- **Generate gVCF**: Generate gVCF output file (default: true)
- **Skip Small Variants**: Skip small variant calling (default: false)
- **Skip SVs**: Skip structural variant calling (default: false)
- **Skip Mosdepth**: Skip QC with mosdepth (default: false)

#### Input Requirements

- **File Format**: FASTQ files or uBAM (unaligned BAM) files from long-read sequencers
- **Batch File**: TSV file with alignment_file, sample_id, and failed_target columns
- **Technology Support**: Compatible with both PacBio HiFi and Oxford Nanopore Technologies (ONT) data

#### Output Files

- **Individual Aligned BAMs**: `{sample_id}_{unique_id}_minimap2.bam` - Individual alignment outputs
- **Merged BAM**: `{sample_id}_minimap2.bam` - Merged alignment for each sample
- **VCF**: `{sample_id}.vcf.gz` - Called variants in standard VCF format
- **gVCF**: `{sample_id}.g.vcf.gz` - Genomic VCF format (if enabled)
- **Structural Variants**: SV calls in VCF format (if enabled)
- **QC Reports**: Quality control metrics and reports

#### Special Features

- **Failed Target Handling**: When `failed_target` is set to `true` in the batch file, the alignment step is automatically skipped for that entry
- **Multiple Files per Sample**: When multiple input files map to the same sample, each produces a uniquely named BAM file that is later merged
- **Sample Catalog Update**: The merged BAM path is automatically added to the workspace SampleCatalog

---

### 3. Somatic Tumor/Tumor-Normal Calling

The Somatic Tumor/Tumor-Normal Calling workflow performs alignment and variant calling for somatic samples, supporting both tumor-normal paired analysis and tumor-only analysis.

#### Workflow Stages

1. **Prepare Directories**: Sets up output directory structure
2. **Alignment with BWA-MEM**: Aligns each sample's FASTQ files independently
3. **Generate Batch Parameter File**: Creates a manifest pairing tumor and normal samples from SampleCatalog
4. **Variant Calling with TNscope**: Performs somatic variant calling using tumor-normal pairs or tumor-only mode

#### Key Features

- Independent alignment of all samples
- Automatic pairing of tumor and normal samples using SampleCatalog relationships
- Tumor-only variant calling if no normal sample is specified in SampleCatalog
- High sensitivity for detecting somatic variants
- Optimized for cancer genomics applications
- Support for multiple sequencing platforms

#### Workflow Parameters

- **Input Folder**: Directory containing FASTQ files for alignment
- **Output Folder**: Directory for alignment and variant calling results
- **Machine Learning Model**: Platform-specific model for optimization
- **Reference File**: FASTA file for alignment and variant calling (defaults to workspace reference)
- **SampleCatalog**: Used to define tumor/normal relationships

#### Input Requirements

- **File Format**: FASTQ files (`.fastq.gz` or `.fq.gz`)
- **SampleCatalog**: Must contain tumor/normal sample relationships
- **Naming Convention**: Files should follow the pattern `{sample_name}_*.fastq.gz`

#### Output Files

- **Aligned BAMs**: `{sample_name}.bam` - Aligned reads for each sample
- **Somatic VCF**: `{tumor_sample}.vcf.gz` - Somatic variants called from tumor-normal pairs or tumor-only
- **Metrics**: Alignment and quality metrics files

---

### 4. Comprehensive Whole-Genome Analysis with PGx

The Comprehensive Whole-Genome Analysis with PGx workflow performs a complete whole-genome analysis including alignment, variant calling, pharmacogenomics (PGx) analysis, and reporting.

#### Workflow Stages

1. **Prepare Directories**: Sets up output directory structure
2. **Alignment with BWA-MEM**: Aligns FASTQ files to a reference genome
3. **Variant Calling with DNAscope**: Calls germline variants from aligned BAM files
4. **Pharmacogenomics Analysis with CypCall**: Performs PGx genotyping
5. **VarSeq PGx Reporting**: Generates PGx reports using VSPGx

#### Key Features

- Complete whole-genome analysis pipeline
- Integrated pharmacogenomics analysis
- Automatic PGx report generation
- SampleCatalog integration for PGx genotypes
- Support for multiple sequencing platforms

#### Workflow Parameters

- **Input Folder**: Directory containing FASTQ files
- **Output Folder**: Directory where results will be stored
- **Machine Learning Model**: Platform-specific model for optimization
- **Reference File**: FASTA file for alignment and variant calling (defaults to workspace reference)
- **Output GVCF**: Generate gVCF format for joint genotyping (default: false)

#### Input Requirements

- **File Format**: FASTQ files (`.fastq.gz` or `.fq.gz`)
- **SampleCatalog**: Expected fields include `PGxGenotypes`, `AlternativeCYP2D6Genotypes`, and `AllelesTested`
- **Naming Convention**: Files should follow the pattern `{sample_name}_*.fastq.gz`

#### Output Files

- **Aligned BAM**: `{sample_name}.bam` - Aligned reads
- **VCF**: `{sample_name}.vcf.gz` - Called variants
- **gVCF**: `{sample_name}.g.vcf.gz` - Genomic VCF format (if enabled)
- **PGx Reports**: Pharmacogenomics analysis reports
- **Metrics**: Alignment, quality, and PGx metrics

---

## Common Features Across Workflows

### File Size Tracking and Runtime Logging

All workflows include comprehensive tracking of:
- Input file sizes (displayed before processing)
- Output file sizes (displayed after processing)
- Execution time (formatted as hours, minutes, seconds)
- Disk space usage

### Sample Catalog Integration

Several workflows automatically update the workspace SampleCatalog:
- Long-read workflow updates catalog with merged BAM paths
- Somatic workflow uses catalog for tumor-normal pairing
- WGS workflow uses catalog for PGx genotype storage

### Platform Support

Short-read workflows support:
- Illumina (WES 2.1, WGS 2.2)
- Element Biosciences (WES 2.1, WGS 2.1)
- MGI (WES 2.1, WGS 2.1)
- Salus (WES 1.0, WGS 1.0)
- Ultima Genomics (WGS 1.1)

Long-read workflows support:
- PacBio HiFi
- Oxford Nanopore Technologies (ONT)

### Advanced Options

Most workflows include advanced options for:
- Custom reference files
- Custom model base paths
- Output format selection (BAM/CRAM, VCF/gVCF)
- Quality control metrics
- Deduplication settings

## Getting Started

1. **Download Prerequisites**: Run the required download tasks for reference files and models
2. **Prepare Input Data**: Organize your FASTQ files or prepare batch TSV files as required
3. **Configure Workspace**: Set up workspace settings including `RESOURCE_PATH` and `REFERENCE_PATH`
4. **Run Workflow**: Select the appropriate workflow for your analysis type and follow the parameter prompts
5. **Review Results**: Check output folders for alignment files, VCF files, and quality metrics

## Additional Resources

- [Sentieon Manual](https://support.sentieon.com/manual/)
- [VarSeq Documentation](https://www.goldenhelix.com/products/VarSeq/documentation/)
- Workspace Settings: Configure resource paths and default references
