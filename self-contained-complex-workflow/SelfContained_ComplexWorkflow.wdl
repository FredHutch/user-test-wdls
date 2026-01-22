version 1.0

# A struct to hold sample-specific parameters (mirrors singleSample in original)
struct ProcessingSample {
    String sampleName
    String sampleId
    String processingGroup
    String analysisType
    Int dataSize
    Array[String] categories
}

####### Self-contained workflow demonstrating complex WDL patterns
####### Mirrors the structure of SCG_10x_AML_Genotyping without external dependencies
workflow SelfContained_ComplexWorkflow {
  input {
    Array[ProcessingSample] batchOfSamples
    Int? itemCount
    # Processing parameters
    Array[String] targetRegions = ["region1", "region2", "region3", "region4", "region5"]
    String processingMode = "standard"
    Int chunkSize = 100
    Boolean enableQC = true
  }

    # Static configuration (mirrors chromosomes array in original)
    Array[String] allRegions = ["region1", "region2", "region3", "region4", "region5", 
                                "region6", "region7", "region8", "region9", "region10"]
    
    # Docker containers (mirrors original pattern)
    String pythonDocker = "python:3.9-slim"
    String bashDocker = "ubuntu:22.04"
    String alpineDocker = "alpine:3.18"

  ## START WORKFLOW
  scatter (sample in batchOfSamples) {
    
    # Initial validation task (mirrors umiTools_validBarcodes)
    call validateInput {
      input:
        sampleName = sample.sampleName + "." + sample.sampleId,
        categories = sample.categories,
        itemCount = itemCount,
        taskDocker = pythonDocker
    }
    
    # Primary processing task (mirrors cellRangerCount as cellRangerGEX)
    call primaryProcessing as processPrimary {
      input:
        sampleName = sample.sampleName,
        dataSize = sample.dataSize,
        processingGroup = sample.processingGroup,
        threads = 4,
        itemCount = itemCount,
        taskDocker = bashDocker
    }
    
    # Secondary processing task (mirrors cellRangerCount as cellRangerENR)
    call primaryProcessing as processSecondary {
      input:
        sampleName = sample.sampleName + "-secondary",
        dataSize = sample.dataSize,
        processingGroup = sample.processingGroup,
        threads = 4,
        itemCount = itemCount,
        taskDocker = bashDocker
    }
    
    # Consensus task (mirrors barcodeConsensus)
    call findConsensus {
      input:
        primaryOutput = processPrimary.outputList,
        secondaryOutput = validateInput.validatedList,
        sampleName = sample.sampleName + "." + sample.sampleId,
        taskDocker = pythonDocker
    }
    
    # Transform and align task (mirrors extractAndAlign)
    call transformAndProcess {
      input:
        inputData = sample.categories,
        consensusList = findConsensus.consensusList,
        baseName = sample.sampleName + "." + sample.sampleId,
        processingMode = processingMode,
        threads = 8,
        taskDocker = bashDocker
    }
    
    # Conversion task (mirrors convertCellRangerDict)
    call convertFormat {
      input:
        inputFile = processPrimary.outputFile,
        taskDocker = alpineDocker,
        threads = 2
    }
    
    # Filter task (mirrors filterCellRanger)
    call filterData {
      input:
        inputFile = convertFormat.convertedFile,
        filterList = findConsensus.consensusList,
        taskDocker = alpineDocker,
        threads = 4
    }
    
    # Matrix generation task (mirrors vartrix)
    call generateMatrix {
      input:
        sampleName = sample.sampleName + "." + sample.sampleId,
        dataFile = convertFormat.convertedFile,
        referenceList = processPrimary.outputList,
        threads = 4,
        taskDocker = pythonDocker
    }
    
    # Header creation task (mirrors createRGHeader)
    call createHeader {
      input:
        itemList = findConsensus.consensusList,
        sampleName = sample.sampleName + "." + sample.sampleId,
        taskDocker = pythonDocker
    }
    
    ### Primary path processing - Split by region, process, then gather
    ### (mirrors splitBambyChr as splitEnrichedbyChr pattern)
    call splitByRegion as splitPrimaryByRegion {
      input:
        fileToSplit = transformAndProcess.processedFile,
        regions = targetRegions,
        taskDocker = bashDocker
    }
    
    # Nested scatter over split files (mirrors scatter over subBam in splitEnrichedbyChr.bams)
    scatter (subFile in splitPrimaryByRegion.splitFiles) {
      
      # Add metadata task (mirrors addReadGroup)
      call addMetadata {
        input:
          inputFile = subFile,
          sampleName = sample.sampleName + "." + sample.sampleId,
          taskDocker = bashDocker
      }
      
      # Preparation task (mirrors prepBam as prepEnriched)
      call prepareData as preparePrimary {
        input:
          dataFile = addMetadata.outputFile,
          chunkSize = chunkSize,
          enableQC = enableQC,
          taskDocker = pythonDocker
      }
      
      # Multi-sample tagging task (mirrors enrichedMultiSample)
      call tagMultiSample as tagPrimary {
        input:
          inputFile = preparePrimary.preparedFile,
          taskDocker = pythonDocker
      }
      
      # Reheader task (mirrors reheader as reheaderEN)
      call updateHeader as updatePrimaryHeader {
        input:
          dataFile = tagPrimary.taggedFile,
          headerText = createHeader.headerText,
          taskDocker = alpineDocker
      }
      
      # Variant calling task (mirrors variantCalling as variantCallingEnriched)
      call callVariants as callPrimaryVariants {
        input:
          dataFile = updatePrimaryHeader.updatedFile,
          baseName = sample.sampleName + "." + sample.sampleId,
          taskDocker = pythonDocker
      }
      
      # Mutect-style calling task (mirrors Mutect2TumorOnly as Mutect2TumorOnlyEnriched)
      call advancedCalling as advancedPrimaryCalling {
        input:
          inputFile = updatePrimaryHeader.updatedFile,
          baseName = sample.sampleName + "." + sample.sampleId,
          taskDocker = pythonDocker
      }
    }
    
    # Combine outputs across regions (mirrors mergeVcfs as combineEnriched)
    call mergeOutputs as combinePrimary {
      input:
        filesToMerge = callPrimaryVariants.variantFile,
        fileIndexes = callPrimaryVariants.variantIndex,
        groupName = sample.sampleName + "." + sample.sampleId + ".PRIMARY.combined",
        taskDocker = bashDocker
    }
    
    # Combine advanced outputs (mirrors mergeVcfs as combineEnrichedMutect2)
    call mergeOutputs as combinePrimaryAdvanced {
      input:
        filesToMerge = advancedPrimaryCalling.outputFile,
        fileIndexes = advancedPrimaryCalling.outputIndex,
        groupName = sample.sampleName + "." + sample.sampleId + ".PRIMARY.advanced",
        taskDocker = bashDocker
    }
    
    # Gather all data files (mirrors gatherBams)
    call gatherFiles {
      input:
        files = updatePrimaryHeader.updatedFile,
        sampleName = sample.sampleName + "." + sample.sampleId,
        taskDocker = bashDocker
    }
    
    # Deduplication task (mirrors dedupUMIs)
    call deduplicateData {
      input:
        inputFile = gatherFiles.gatheredFile,
        indexFile = gatherFiles.gatheredIndex,
        baseName = sample.sampleName + "." + sample.sampleId,
        taskDocker = pythonDocker
    }
    
    # Index task (mirrors indexBam)
    call indexFile {
      input:
        inputFile = deduplicateData.dedupedFile,
        taskDocker = alpineDocker,
        threads = 4
    }
    
    # Depth calculation task (mirrors targetReadDepth as umiDepth)
    call calculateDepth as calculateDedupDepth {
      input:
        dataFile = indexFile.indexedFile,
        indexFile = indexFile.fileIndex,
        sampleName = sample.sampleName + "." + sample.sampleId + ".dedup",
        taskDocker = pythonDocker
    }
    
    # Another depth calculation (mirrors targetReadDepth)
    call calculateDepth {
      input:
        dataFile = gatherFiles.gatheredFile,
        indexFile = gatherFiles.gatheredIndex,
        sampleName = sample.sampleName + "." + sample.sampleId,
        taskDocker = pythonDocker
    }
    
    # Query task (mirrors vcfQuery as queryEnriched)
    call queryOutput as queryPrimary {
      input:
        fileToQuery = combinePrimary.mergedFile,
        baseName = sample.sampleName + "." + sample.sampleId + ".PRIMARY",
        taskDocker = alpineDocker
    }
    
    # Query advanced output (mirrors vcfQuery as queryEnrichedMutect)
    call queryOutput as queryPrimaryAdvanced {
      input:
        fileToQuery = combinePrimaryAdvanced.mergedFile,
        baseName = sample.sampleName + "." + sample.sampleId + ".PRIMARY.adv",
        taskDocker = alpineDocker
    }
    
    # Annotation task (mirrors annovar as annovarEnriched)
    call annotateResults as annotatePrimary {
      input:
        inputFile = queryPrimary.queriedFile,
        annotationType = processingMode,
        taskDocker = pythonDocker
    }
    
    # Annotate advanced results (mirrors annovar as annovarEnrichedMutect)
    call annotateResults as annotatePrimaryAdvanced {
      input:
        inputFile = queryPrimaryAdvanced.queriedFile,
        annotationType = processingMode,
        taskDocker = pythonDocker
    }
    
    # Format results task (mirrors formatSCVariants as formatSCEN)
    call formatResults as formatPrimary {
      input:
        inputFile = combinePrimary.mergedFile,
        sampleName = sample.sampleName + "." + sample.sampleId + ".PRIMARY",
        taskDocker = pythonDocker
    }
    
    # Format advanced results (mirrors formatSCVariantsforMutect2 as formatSCENMutect2)
    call formatAdvancedResults as formatPrimaryAdvanced {
      input:
        inputFile = combinePrimaryAdvanced.mergedFile,
        sampleName = sample.sampleName + "." + sample.sampleId + ".PRIMARY",
        taskDocker = pythonDocker
    }
    
    ## Secondary path processing (mirrors GEX library variant calling)
    call splitByRegion as splitSecondaryByRegion {
      input:
        fileToSplit = filterData.filteredFile,
        regions = targetRegions,
        taskDocker = bashDocker
    }
    
    scatter (subFileSecondary in splitSecondaryByRegion.splitFiles) {
      
      call prepareData as prepareSecondary {
        input:
          dataFile = subFileSecondary,
          chunkSize = chunkSize,
          enableQC = enableQC,
          taskDocker = pythonDocker
      }
      
      call tagMultiSample as tagSecondary {
        input:
          inputFile = prepareSecondary.preparedFile,
          taskDocker = pythonDocker
      }
      
      call updateHeader as updateSecondaryHeader {
        input:
          dataFile = tagSecondary.taggedFile,
          headerText = createHeader.headerText,
          taskDocker = alpineDocker
      }
      
      call callVariants as callSecondaryVariants {
        input:
          dataFile = updateSecondaryHeader.updatedFile,
          baseName = sample.sampleName + "." + sample.sampleId,
          taskDocker = pythonDocker
      }
    }
    
    # Combine secondary outputs (mirrors mergeVcfs as combineGEX)
    call mergeOutputs as combineSecondary {
      input:
        filesToMerge = callSecondaryVariants.variantFile,
        fileIndexes = callSecondaryVariants.variantIndex,
        groupName = sample.sampleName + "." + sample.sampleId + ".SECONDARY.combined",
        taskDocker = bashDocker
    }
    
    call queryOutput as querySecondary {
      input:
        fileToQuery = combineSecondary.mergedFile,
        baseName = sample.sampleName + "." + sample.sampleId + ".SECONDARY",
        taskDocker = alpineDocker
    }
    
    call annotateResults as annotateSecondary {
      input:
        inputFile = querySecondary.queriedFile,
        annotationType = processingMode,
        taskDocker = pythonDocker
    }
    
    call formatResults as formatSecondary {
      input:
        inputFile = combineSecondary.mergedFile,
        sampleName = sample.sampleName + "." + sample.sampleId + ".SECONDARY",
        taskDocker = pythonDocker
    }
    
    # Additional secondary path processing (mirrors TRYING TO COLLECT UMI DATA FROM GEX section)
    call transformAndProcess as transformSecondary {
      input:
        inputData = sample.categories,
        consensusList = findConsensus.consensusList,
        baseName = sample.sampleName + "." + sample.sampleId,
        processingMode = processingMode,
        threads = 8,
        taskDocker = bashDocker
    }
    
    call splitByRegion as splitSecondary2ByRegion {
      input:
        fileToSplit = transformSecondary.processedFile,
        regions = targetRegions,
        taskDocker = bashDocker
    }
    
    scatter (subFileSecondary2 in splitSecondary2ByRegion.splitFiles) {
      
      call addMetadata as addMetadataSecondary2 {
        input:
          inputFile = subFileSecondary2,
          sampleName = sample.sampleName + "." + sample.sampleId,
          taskDocker = bashDocker
      }
      
      call prepareData as prepareSecondary2 {
        input:
          dataFile = addMetadataSecondary2.outputFile,
          chunkSize = chunkSize,
          enableQC = enableQC,
          taskDocker = pythonDocker
      }
      
      call tagMultiSample as tagSecondary2 {
        input:
          inputFile = prepareSecondary2.preparedFile,
          taskDocker = pythonDocker
      }
      
      call updateHeader as updateSecondary2Header {
        input:
          dataFile = tagSecondary2.taggedFile,
          headerText = createHeader.headerText,
          taskDocker = alpineDocker
      }
    }
    
    call gatherFiles as gatherSecondary2 {
      input:
        files = updateSecondary2Header.updatedFile,
        sampleName = sample.sampleName + "." + sample.sampleId,
        taskDocker = bashDocker
    }
    
    call deduplicateData as deduplicateSecondary2 {
      input:
        inputFile = gatherSecondary2.gatheredFile,
        indexFile = gatherSecondary2.gatheredIndex,
        baseName = sample.sampleName + "." + sample.sampleId,
        taskDocker = pythonDocker
    }
    
    call indexFile as indexSecondary2 {
      input:
        inputFile = deduplicateSecondary2.dedupedFile,
        taskDocker = alpineDocker,
        threads = 4
    }
    
    call calculateDepth as calculateDedupDepthSecondary2 {
      input:
        dataFile = indexSecondary2.indexedFile,
        indexFile = indexSecondary2.fileIndex,
        sampleName = sample.sampleName + "." + sample.sampleId + ".dedup",
        taskDocker = pythonDocker
    }
    
    call calculateDepth as calculateDepthSecondary2 {
      input:
        dataFile = gatherSecondary2.gatheredFile,
        indexFile = gatherSecondary2.gatheredIndex,
        sampleName = sample.sampleName + "." + sample.sampleId,
        taskDocker = pythonDocker
    }
  }

  # Outputs that will be retained when execution is complete
  output {
    Array[File] consensusLists = findConsensus.consensusList
    Array[File] primaryOutputFile = processPrimary.outputFile
    Array[File] primaryOutputIndex = processPrimary.outputIndex
    Array[File] primaryOutputList = processPrimary.outputList
    Array[File] primaryFilteredList = processPrimary.filteredList
    Array[File] primaryFeatures = processPrimary.features
    Array[File] primaryMatrix = processPrimary.matrix
    Array[Array[File]] primaryOutputDir = processPrimary.outputDir
    Array[File] gatheredPrimaryFile = gatherFiles.gatheredFile
    Array[File] gatheredPrimaryIndex = gatherFiles.gatheredIndex
    Array[File] gatheredSecondaryFile = gatherSecondary2.gatheredFile
    Array[File] gatheredSecondaryIndex = gatherSecondary2.gatheredIndex
    Array[File] primaryFormattedResults = formatPrimary.formattedFile
    Array[File] primaryAdvancedFormattedResults = formatPrimaryAdvanced.formattedFile
    Array[File] secondaryFormattedResults = formatSecondary.formattedFile
    Array[File] validatedLists = validateInput.validatedList
    Array[File] countsPlots = validateInput.countsPlot
    Array[File] annotatedPrimary = annotatePrimary.annotatedTable
    Array[File] annotatedPrimaryFile = annotatePrimary.annotatedFile
    Array[File] annotatedPrimaryAdvanced = annotatePrimaryAdvanced.annotatedTable
    Array[File] annotatedPrimaryAdvancedFile = annotatePrimaryAdvanced.annotatedFile
    Array[File] annotatedSecondary = annotateSecondary.annotatedTable
    Array[File] annotatedSecondaryFile = annotateSecondary.annotatedFile
    Array[File] matrixResults = generateMatrix.matrixFile
    Array[File] depthResults = calculateDepth.depthFile
    Array[File] depthResultsSecondary = calculateDepthSecondary2.depthFile
    Array[File] dedupDepthResults = calculateDedupDepth.depthFile
    Array[File] dedupDepthResultsSecondary = calculateDedupDepthSecondary2.depthFile
    Array[File] secondaryOutputFile = processSecondary.outputFile
    Array[File] secondaryOutputIndex = processSecondary.outputIndex
    Array[File] secondaryOutputList = processSecondary.outputList
    Array[File] secondaryFilteredList = processSecondary.filteredList
    Array[File] secondaryFeatures = processSecondary.features
    Array[File] secondaryMatrix = processSecondary.matrix
    Array[Array[File]] secondaryOutputDir = processSecondary.outputDir
    Array[Array[File]] advancedPrimaryOutputFiles = advancedPrimaryCalling.outputFile
    Array[Array[File]] advancedPrimaryOutputIndexes = advancedPrimaryCalling.outputIndex
  }
} # End workflow


#### TASK DEFINITIONS

# Add metadata to file (mirrors addReadGroup)
task addMetadata {
  input {
    File inputFile
    String sampleName
    String taskDocker
  }
  String stem = basename(inputFile, ".txt")
  command <<<
    set -eo pipefail
    echo "Adding metadata for sample: ~{sampleName}" > ~{stem}.meta.txt
    cat ~{inputFile} >> ~{stem}.meta.txt
    echo "METADATA_LIBRARY=lib" >> ~{stem}.meta.txt
    echo "METADATA_PLATFORM=platform1" >> ~{stem}.meta.txt
    echo "METADATA_UNIT=unit1" >> ~{stem}.meta.txt
    echo "METADATA_SAMPLE=~{sampleName}" >> ~{stem}.meta.txt
  >>>
  runtime {
    docker: taskDocker
  }
  output {
    File outputFile = "~{stem}.meta.txt"
  }
}


# Annotation task (mirrors annovar)
task annotateResults {
  input {
    File inputFile
    String annotationType
    String taskDocker
  }
  String baseName = basename(inputFile, ".txt")
  command <<<
    set -eo pipefail
    
    # Generate annotated output file
    echo "# Annotated results for: ~{baseName}" > ~{baseName}.annotated.txt
    echo "# Annotation type: ~{annotationType}" >> ~{baseName}.annotated.txt
    echo "CHROM	POS	REF	ALT	GENE	FUNCTION	ANNOTATION" >> ~{baseName}.annotated.txt
    echo "chr1	12345	A	G	GENE1	exonic	synonymous" >> ~{baseName}.annotated.txt
    echo "chr2	67890	C	T	GENE2	intronic	." >> ~{baseName}.annotated.txt
    echo "chr3	11111	G	A	GENE3	exonic	nonsynonymous" >> ~{baseName}.annotated.txt
    
    # Generate annotated table
    echo "# Annotated table for: ~{baseName}" > ~{baseName}.annotated.table.txt
    echo "Variant_ID	Gene	Function	ExonicFunc	AAChange" >> ~{baseName}.annotated.table.txt
    echo "chr1:12345:A:G	GENE1	exonic	synonymous	p.A100A" >> ~{baseName}.annotated.table.txt
    echo "chr2:67890:C:T	GENE2	intronic	.	." >> ~{baseName}.annotated.table.txt
    echo "chr3:11111:G:A	GENE3	exonic	nonsynonymous	p.G200R" >> ~{baseName}.annotated.table.txt
  >>>
  output {
    File annotatedFile = "~{baseName}.annotated.txt"
    File annotatedTable = "~{baseName}.annotated.table.txt"
  }
  runtime {
    docker: taskDocker
    cpu: 1
    memory: "512MB"
  }
}


# Consensus finding task (mirrors barcodeConsensus)
task findConsensus {
  input {
    File primaryOutput
    File secondaryOutput
    String sampleName
    String taskDocker
  }
  command <<<
    set -eo pipefail
    
    # Generate consensus list from both inputs
    echo "# Consensus items for ~{sampleName}" > ~{sampleName}.consensus.txt
    echo "ITEM001" >> ~{sampleName}.consensus.txt
    echo "ITEM002" >> ~{sampleName}.consensus.txt
    echo "ITEM003" >> ~{sampleName}.consensus.txt
    echo "ITEM004" >> ~{sampleName}.consensus.txt
    echo "ITEM005" >> ~{sampleName}.consensus.txt
  >>>
  output {
    File consensusList = "~{sampleName}.consensus.txt"
  }
  runtime {
    cpu: 1
    memory: "512MB"
    docker: taskDocker
  }
}


# Primary processing task (mirrors cellRangerCount)
task primaryProcessing {
  input {
    String sampleName
    Int dataSize
    String processingGroup
    String taskDocker
    Int threads
    Int? itemCount
  }
  command <<<
    set -eo pipefail
    mkdir -p outputdir
    
    # Generate main output file
    echo "# Processed data for ~{sampleName}" > ~{sampleName}.processed.txt
    echo "DATA_SIZE=~{dataSize}" >> ~{sampleName}.processed.txt
    echo "GROUP=~{processingGroup}" >> ~{sampleName}.processed.txt
    for i in $(seq 1 10); do
      echo "RECORD_$i: value_$i" >> ~{sampleName}.processed.txt
    done
    
    # Generate index file
    echo "INDEX for ~{sampleName}.processed.txt" > ~{sampleName}.processed.txt.idx
    
    # Generate list file
    echo "# Item list for ~{sampleName}" > ~{sampleName}.items.txt
    for i in $(seq 1 5); do
      echo "ITEM_$i" >> ~{sampleName}.items.txt
    done
    
    # Generate filtered list
    echo "# Filtered items for ~{sampleName}" > ~{sampleName}.filtered.items.txt
    for i in $(seq 1 3); do
      echo "FILTERED_ITEM_$i" >> ~{sampleName}.filtered.items.txt
    done
    
    # Generate features file
    echo "# Features for ~{sampleName}" > ~{sampleName}.features.txt
    echo "FEATURE1	Gene1	Gene Expression" >> ~{sampleName}.features.txt
    echo "FEATURE2	Gene2	Gene Expression" >> ~{sampleName}.features.txt
    
    # Generate matrix file
    echo "%%MatrixMarket matrix coordinate integer general" > ~{sampleName}.matrix.mtx
    echo "% Generated matrix for ~{sampleName}" >> ~{sampleName}.matrix.mtx
    echo "100 50 25" >> ~{sampleName}.matrix.mtx
    
    # Generate output directory files
    echo "Summary for ~{sampleName}" > outputdir/summary.txt
    echo "Metrics for ~{sampleName}" > outputdir/metrics.txt
  >>>
  output {
    File outputFile = "~{sampleName}.processed.txt"
    File outputIndex = "~{sampleName}.processed.txt.idx"
    File outputList = "~{sampleName}.items.txt"
    File filteredList = "~{sampleName}.filtered.items.txt"
    File features = "~{sampleName}.features.txt"
    File matrix = "~{sampleName}.matrix.mtx"
    Array[File] outputDir = glob("outputdir/*")
  }
  runtime {
    docker: taskDocker
    cpu: threads
  }
}


# Tag multi-sample task (mirrors cellrangerMultiSample / enrichedMultiSample)
task tagMultiSample {
  input {
    File inputFile
    String taskDocker
  }
  String nextFile = basename(inputFile, ".txt") + ".tagged.txt"
  command <<<
    set -eo pipefail
    echo "# Tagged version of input" > ~{nextFile}
    cat ~{inputFile} >> ~{nextFile}
    echo "TAG_ADDED=true" >> ~{nextFile}
    echo "TAG_TYPE=multi_sample" >> ~{nextFile}
  >>>
  runtime {
    docker: taskDocker
  }
  output {
    File taggedFile = "~{nextFile}"
  }
}


# Convert format task (mirrors convertCellRangerDict)
task convertFormat {
  input {
    File inputFile
    String taskDocker
    Int threads
  }
  String filename = basename(inputFile, ".txt")
  command <<<
    set -eo pipefail
    echo "# Converted format for ~{filename}" > ~{filename}.converted.txt
    cat ~{inputFile} >> ~{filename}.converted.txt
    echo "FORMAT_VERSION=2.0" >> ~{filename}.converted.txt
    
    # Generate index
    echo "INDEX for ~{filename}.converted.txt" > ~{filename}.converted.txt.idx
  >>>
  output {
    File convertedFile = "~{filename}.converted.txt"
    File convertedIndex = "~{filename}.converted.txt.idx"
  }
  runtime {
    docker: taskDocker
    cpu: threads
  }
}


# Deduplication task (mirrors dedupUMIs)
task deduplicateData {
  input {
    File inputFile
    File indexFile
    String baseName
    String taskDocker
  }
  command <<<
    set -eo pipefail
    # Touch index to ensure it's used
    touch ~{indexFile}
    
    echo "# Deduplicated data for ~{baseName}" > ~{baseName}.dedup.txt
    cat ~{inputFile} >> ~{baseName}.dedup.txt
    echo "DEDUP_STATUS=complete" >> ~{baseName}.dedup.txt
    echo "UNIQUE_ITEMS=42" >> ~{baseName}.dedup.txt
  >>>
  output {
    File dedupedFile = "~{baseName}.dedup.txt"
  }
  runtime {
    memory: "512MB"
    cpu: 2
    docker: taskDocker
  }
}


# Create header task (mirrors createRGHeader)
task createHeader {
  input {
    File itemList
    String sampleName
    String taskDocker
  }
  command <<<
    set -eo pipefail
    echo "# Header entries for ~{sampleName}" > ~{sampleName}.header.txt
    while read -r item; do
      if [[ ! "$item" =~ ^# ]]; then
        echo "@HD	ID:$item	PL:PLATFORM	LB:$item	SM:$item" >> ~{sampleName}.header.txt
      fi
    done < ~{itemList}
  >>>
  output {
    File headerText = "~{sampleName}.header.txt"
  }
  runtime {
    docker: taskDocker
  }
}


# Transform and process task (mirrors extractAndAlign)
task transformAndProcess {
  input {
    Array[String] inputData
    File consensusList
    String baseName
    String processingMode
    String taskDocker
    Int threads
  }
  command <<<
    set -eo pipefail
    
    echo "# Transformed and processed data" > ~{baseName}.~{processingMode}.processed.txt
    echo "MODE=~{processingMode}" >> ~{baseName}.~{processingMode}.processed.txt
    echo "INPUT_CATEGORIES=~{sep=',' inputData}" >> ~{baseName}.~{processingMode}.processed.txt
    
    # Add consensus items
    echo "# Consensus items:" >> ~{baseName}.~{processingMode}.processed.txt
    cat ~{consensusList} >> ~{baseName}.~{processingMode}.processed.txt
    
    # Generate some processed records
    for i in $(seq 1 20); do
      echo "PROCESSED_RECORD_$i: data_$i" >> ~{baseName}.~{processingMode}.processed.txt
    done
    
    # Generate index
    echo "INDEX for ~{baseName}.~{processingMode}.processed.txt" > ~{baseName}.~{processingMode}.processed.txt.idx
  >>>
  output {
    File processedFile = "~{baseName}.~{processingMode}.processed.txt"
    File processedIndex = "~{baseName}.~{processingMode}.processed.txt.idx"
  }
  runtime {
    memory: "1GB"
    cpu: threads
    docker: taskDocker
  }
}


# Filter data task (mirrors filterCellRanger)
task filterData {
  input {
    File inputFile
    File filterList
    String taskDocker
    Int threads
  }
  String filename = basename(inputFile, ".txt")
  command <<<
    set -eo pipefail
    
    echo "# Filtered data from ~{filename}" > ~{filename}.filtered.txt
    cat ~{inputFile} >> ~{filename}.filtered.txt
    echo "# Applied filter from list:" >> ~{filename}.filtered.txt
    cat ~{filterList} >> ~{filename}.filtered.txt
    
    # Generate index
    echo "INDEX for ~{filename}.filtered.txt" > ~{filename}.filtered.txt.idx
  >>>
  output {
    File filteredFile = "~{filename}.filtered.txt"
    File filteredIndex = "~{filename}.filtered.txt.idx"
  }
  runtime {
    docker: taskDocker
    cpu: threads
  }
}


# Format results task (mirrors formatSCVariants)
task formatResults {
  input {
    File inputFile
    String sampleName
    String taskDocker
  }
  command <<<
    set -eo pipefail
    
    echo "Chr,Start,REF,ALT,variantID,cellBarcode,genotype,DP,AD" > ~{sampleName}.formatted.csv
    echo "chr1,12345,A,G,chr1-12345-A-G,CELL001,0/1,50,25" >> ~{sampleName}.formatted.csv
    echo "chr2,67890,C,T,chr2-67890-C-T,CELL002,1/1,40,40" >> ~{sampleName}.formatted.csv
    echo "chr3,11111,G,A,chr3-11111-G-A,CELL001,0/1,60,30" >> ~{sampleName}.formatted.csv
  >>>
  output {
    File formattedFile = "~{sampleName}.formatted.csv"
  }
  runtime {
    docker: taskDocker
  }
}


# Format advanced results task (mirrors formatSCVariantsforMutect2)
task formatAdvancedResults {
  input {
    File inputFile
    String sampleName
    String taskDocker
  }
  command <<<
    set -eo pipefail
    
    echo "Chr,Start,REF,ALT,variantID,FILTER,cellBarcode,rawGenotype,GT,AD,AF,DP" > ~{sampleName}.advanced.formatted.csv
    echo "chr1,12345,A,G,chr1-12345-A-G,PASS,CELL001,0/1:25,30:0.45:55,0/1,25,30,0.45,55" >> ~{sampleName}.advanced.formatted.csv
    echo "chr2,67890,C,T,chr2-67890-C-T,PASS,CELL002,1/1:40,0:1.0:40,1/1,40,0,1.0,40" >> ~{sampleName}.advanced.formatted.csv
  >>>
  output {
    File formattedFile = "~{sampleName}.advanced.formatted.csv"
  }
  runtime {
    docker: taskDocker
  }
}


# Gather files task (mirrors gatherBams)
task gatherFiles {
  input {
    Array[File] files
    String sampleName
    String taskDocker
  }
  command <<<
    set -eo pipefail
    
    echo "# Gathered data for ~{sampleName}" > ~{sampleName}.gathered.txt
    for f in ~{sep=' ' files}; do
      cat "$f" >> ~{sampleName}.gathered.txt
      echo "---" >> ~{sampleName}.gathered.txt
    done
    
    # Generate index
    echo "INDEX for ~{sampleName}.gathered.txt" > ~{sampleName}.gathered.txt.idx
  >>>
  runtime {
    cpu: 4
    docker: taskDocker
  }
  output {
    File gatheredFile = "~{sampleName}.gathered.txt"
    File gatheredIndex = "~{sampleName}.gathered.txt.idx"
  }
}


# Index file task (mirrors indexBam)
task indexFile {
  input {
    File inputFile
    String taskDocker
    Int threads
  }
  String fileName = basename(inputFile)
  command <<<
    set -eo pipefail
    cp ~{inputFile} ~{fileName}
    echo "INDEX for ~{fileName}" > ~{fileName}.idx
  >>>
  output {
    File indexedFile = "~{fileName}"
    File fileIndex = "~{fileName}.idx"
  }
  runtime {
    docker: taskDocker
    cpu: threads
  }
}


# Merge outputs task (mirrors mergeVcfs)
task mergeOutputs {
  input {
    Array[File] filesToMerge
    Array[File] fileIndexes
    String groupName
    String taskDocker
  }
  command <<<
    set -eo pipefail
    
    echo "# Merged output for ~{groupName}" > ~{groupName}.merged.txt
    for f in ~{sep=' ' filesToMerge}; do
      cat "$f" >> ~{groupName}.merged.txt
      echo "---MERGED_SECTION---" >> ~{groupName}.merged.txt
    done
    
    # Generate index
    echo "INDEX for ~{groupName}.merged.txt" > ~{groupName}.merged.txt.idx
  >>>
  runtime {
    docker: taskDocker
    cpu: 1
    memory: "512MB"
  }
  output {
    File mergedFile = "~{groupName}.merged.txt"
    File mergedIndex = "~{groupName}.merged.txt.idx"
  }
}


# Prepare data task (mirrors prepBam)
task prepareData {
  input {
    File dataFile
    Int chunkSize
    Boolean enableQC
    String taskDocker
  }
  String stem = basename(dataFile, ".txt")
  command <<<
    set -eo pipefail
    
    echo "# Prepared data from ~{stem}" > ~{stem}.prepared.txt
    cat ~{dataFile} >> ~{stem}.prepared.txt
    echo "CHUNK_SIZE=~{chunkSize}" >> ~{stem}.prepared.txt
    echo "QC_ENABLED=~{enableQC}" >> ~{stem}.prepared.txt
    echo "PREPARATION_COMPLETE=true" >> ~{stem}.prepared.txt
    
    # Generate index
    echo "INDEX for ~{stem}.prepared.txt" > ~{stem}.prepared.idx
    
    # Generate metrics
    echo "# Preparation metrics" > ~{stem}.prep_metrics.txt
    echo "INPUT_RECORDS=100" >> ~{stem}.prep_metrics.txt
    echo "OUTPUT_RECORDS=95" >> ~{stem}.prep_metrics.txt
  >>>
  runtime {
    docker: taskDocker
    cpu: 4
  }
  output {
    File preparedFile = "~{stem}.prepared.txt"
    File preparedIndex = "~{stem}.prepared.idx"
    File prepMetrics = "~{stem}.prep_metrics.txt"
  }
}


# Update header task (mirrors reheader)
task updateHeader {
  input {
    File dataFile
    File headerText
    String taskDocker
  }
  String outfile = basename(dataFile, ".txt")
  command <<<
    set -eo pipefail
    
    echo "# Updated header version" > ~{outfile}.updated.txt
    cat ~{headerText} >> ~{outfile}.updated.txt
    echo "---DATA_START---" >> ~{outfile}.updated.txt
    cat ~{dataFile} >> ~{outfile}.updated.txt
    
    # Generate index
    echo "INDEX for ~{outfile}.updated.txt" > ~{outfile}.updated.txt.idx
  >>>
  output {
    File updatedFile = "~{outfile}.updated.txt"
    File updatedIndex = "~{outfile}.updated.txt.idx"
  }
  runtime {
    docker: taskDocker
  }
}


# Split by region task (mirrors splitBambyChr)
task splitByRegion {
  input {
    File fileToSplit
    Array[String] regions
    String taskDocker
  }
  command <<<
    set -eo pipefail
    for region in ~{sep=' ' regions}; do
      echo "# Split data for region: $region" > ${region}.txt
      cat ~{fileToSplit} >> ${region}.txt
      echo "REGION=$region" >> ${region}.txt
    done
  >>>
  output {
    Array[File] splitFiles = glob("*.txt")
  }
  runtime {
    docker: taskDocker
    cpu: 4
  }
}


# Calculate depth task (mirrors targetReadDepth)
task calculateDepth {
  input {
    File dataFile
    File indexFile
    String sampleName
    String taskDocker
  }
  command <<<
    set -eo pipefail
    # Touch index to use it
    touch ~{indexFile}
    
    echo "# Depth calculations for ~{sampleName}" > ~{sampleName}.depth.txt
    echo "CHROM	POS	DEPTH	SAMPLE" >> ~{sampleName}.depth.txt
    echo "chr1	12345	50	~{sampleName}" >> ~{sampleName}.depth.txt
    echo "chr1	12346	52	~{sampleName}" >> ~{sampleName}.depth.txt
    echo "chr2	67890	45	~{sampleName}" >> ~{sampleName}.depth.txt
    echo "chr3	11111	60	~{sampleName}" >> ~{sampleName}.depth.txt
  >>>
  output {
    File depthFile = "~{sampleName}.depth.txt"
  }
  runtime {
    cpu: 6
    memory: "512MB"
    docker: taskDocker
  }
}


# Validate input task (mirrors umiTools_validBarcodes)
task validateInput {
  input {
    String sampleName
    Array[String] categories
    Int? itemCount
    String taskDocker
  }
  command <<<
    set -eo pipefail
    
    # Generate validated list
    echo "# Validated items for ~{sampleName}" > ~{sampleName}.validated.txt
    for i in $(seq 1 ~{default=10 itemCount}); do
      echo "VALID_ITEM_$i" >> ~{sampleName}.validated.txt
    done
    
    # Generate counts plot (as text representation)
    echo "# Counts plot data for ~{sampleName}" > ~{sampleName}_counts_plot.txt
    echo "ITEM	COUNT" >> ~{sampleName}_counts_plot.txt
    for i in $(seq 1 10); do
      count=$((100 - i * 5))
      echo "ITEM_$i	$count" >> ~{sampleName}_counts_plot.txt
    done
    
    # Generate knee plot
    echo "# Knee plot data for ~{sampleName}" > ~{sampleName}_knee_plot.txt
    echo "RANK	VALUE" >> ~{sampleName}_knee_plot.txt
    for i in $(seq 1 10); do
      value=$((1000 / i))
      echo "$i	$value" >> ~{sampleName}_knee_plot.txt
    done
  >>>
  output {
    File validatedList = "~{sampleName}.validated.txt"
    File countsPlot = "~{sampleName}_counts_plot.txt"
    File kneePlot = "~{sampleName}_knee_plot.txt"
  }
  runtime {
    memory: "512MB"
    docker: taskDocker
    cpu: 1
  }
}


# Variant calling task (mirrors variantCalling)
task callVariants {
  input {
    File dataFile
    String baseName
    String taskDocker
  }
  command <<<
    set -eo pipefail
    
    # Generate variant file
    echo "##fileformat=VCFv4.2" > ~{baseName}.variants.txt
    echo "##source=SelfContainedWorkflow" >> ~{baseName}.variants.txt
    echo "#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO	FORMAT	SAMPLE" >> ~{baseName}.variants.txt
    echo "chr1	12345	.	A	G	100	PASS	DP=50	GT:DP:AD	0/1:50:25,25" >> ~{baseName}.variants.txt
    echo "chr2	67890	.	C	T	150	PASS	DP=40	GT:DP:AD	1/1:40:0,40" >> ~{baseName}.variants.txt
    echo "chr3	11111	.	G	A	80	PASS	DP=60	GT:DP:AD	0/1:60:30,30" >> ~{baseName}.variants.txt
    
    # Generate index
    echo "INDEX for ~{baseName}.variants.txt" > ~{baseName}.variants.txt.idx
  >>>
  runtime {
    docker: taskDocker
    cpu: 8
  }
  output {
    File variantFile = "~{baseName}.variants.txt"
    File variantIndex = "~{baseName}.variants.txt.idx"
  }
}


# Matrix generation task (mirrors vartrix)
task generateMatrix {
  input {
    String sampleName
    File dataFile
    File referenceList
    Int threads
    String taskDocker
  }
  command <<<
    set -eo pipefail
    
    echo "%%MatrixMarket matrix coordinate integer general" > ~{sampleName}.matrix.mtx
    echo "% Generated by SelfContainedWorkflow" >> ~{sampleName}.matrix.mtx
    echo "% Sample: ~{sampleName}" >> ~{sampleName}.matrix.mtx
    echo "100 50 25" >> ~{sampleName}.matrix.mtx
    echo "1 1 5" >> ~{sampleName}.matrix.mtx
    echo "2 3 10" >> ~{sampleName}.matrix.mtx
    echo "5 10 15" >> ~{sampleName}.matrix.mtx
  >>>
  runtime {
    cpu: threads
    memory: "512MB"
    docker: taskDocker
  }
  output {
    File matrixFile = "~{sampleName}.matrix.mtx"
  }
}


# Query output task (mirrors vcfQuery)
task queryOutput {
  input {
    File fileToQuery
    String baseName
    String taskDocker
  }
  command <<<
    set -eo pipefail
    
    echo "# Queried output for ~{baseName}" > ~{baseName}.queried.txt
    head -8 ~{fileToQuery} >> ~{baseName}.queried.txt
  >>>
  runtime {
    cpu: 1
    memory: "512MB"
    docker: taskDocker
  }
  output {
    File queriedFile = "~{baseName}.queried.txt"
  }
}


# Advanced calling task (mirrors Mutect2TumorOnly)
task advancedCalling {
  input {
    File inputFile
    String baseName
    String taskDocker
  }
  command <<<
    set -eo pipefail
    
    # Generate advanced variant calls
    echo "##fileformat=VCFv4.2" > ~{baseName}.advanced.txt
    echo "##source=AdvancedCaller" >> ~{baseName}.advanced.txt
    echo "##FILTER=<ID=PASS,Description=\"All filters passed\">" >> ~{baseName}.advanced.txt
    echo "#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO	FORMAT	SAMPLE" >> ~{baseName}.advanced.txt
    echo "chr1	12345	.	A	G	100	PASS	DP=50;AF=0.5	GT:AD:AF:DP	0/1:25,25:0.5:50" >> ~{baseName}.advanced.txt
    echo "chr2	67890	.	C	T	150	PASS	DP=40;AF=1.0	GT:AD:AF:DP	1/1:0,40:1.0:40" >> ~{baseName}.advanced.txt
    
    # Generate index
    echo "INDEX for ~{baseName}.advanced.txt" > ~{baseName}.advanced.txt.idx
  >>>
  runtime {
    docker: taskDocker
    memory: "512MB"
    cpu: 2
  }
  output {
    File outputFile = "~{baseName}.advanced.txt"
    File outputIndex = "~{baseName}.advanced.txt.idx"
  }
}