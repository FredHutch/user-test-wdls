## Simple Hello World Task Chain
## Demonstrates multiple linked task calls for testing task linkage functionality

version 1.0

#### WORKFLOW DEFINITION ####

workflow hello_world_chain {
  meta {
    author: "WILDS Development Team"
    email: "wilds@fredhutch.org"
    description: "Simple hello world workflow with multiple chained task calls"
    outputs: {
        all_outputs: "Array of all individual task output files",
        summary: "Summary file combining all task outputs"
    }
  }

  # Call the same task multiple times with different aliases and messages
  call hello_world as hello_world_1 { input:
    message = "Task 1",
    previous_message = ""
  }

  call hello_world as hello_world_2 { input:
    message = "Task 2",
    previous_message = read_string(hello_world_1.output_file)
  }

  call hello_world as hello_world_3 { input:
    message = "Task 3",
    previous_message = read_string(hello_world_2.output_file)
  }

  call hello_world as hello_world_4 { input:
    message = "Task 4",
    previous_message = read_string(hello_world_3.output_file)
  }

  call hello_world as hello_world_5 { input:
    message = "Task 5",
    previous_message = read_string(hello_world_4.output_file)
  }

  call hello_world as hello_world_6 { input:
    message = "Task 6",
    previous_message = read_string(hello_world_5.output_file)
  }

  call hello_world as hello_world_7 { input:
    message = "Task 7",
    previous_message = read_string(hello_world_6.output_file)
  }

  call hello_world as hello_world_8 { input:
    message = "Task 8",
    previous_message = read_string(hello_world_7.output_file)
  }

  call hello_world as hello_world_9 { input:
    message = "Task 9",
    previous_message = read_string(hello_world_8.output_file)
  }

  call hello_world as hello_world_10 { input:
    message = "Task 10",
    previous_message = read_string(hello_world_9.output_file)
  }

  call hello_world as hello_world_11 { input:
    message = "Task 11",
    previous_message = read_string(hello_world_10.output_file)
  }

  call hello_world as hello_world_12 { input:
    message = "Task 12",
    previous_message = read_string(hello_world_11.output_file)
  }

  call hello_world as hello_world_13 { input:
    message = "Task 13",
    previous_message = read_string(hello_world_12.output_file)
  }

  call hello_world as hello_world_14 { input:
    message = "Task 14",
    previous_message = read_string(hello_world_13.output_file)
  }

  call hello_world as hello_world_15 { input:
    message = "Task 15",
    previous_message = read_string(hello_world_14.output_file)
  }

  call hello_world as hello_world_16 { input:
    message = "Task 16",
    previous_message = read_string(hello_world_15.output_file)
  }

  call hello_world as hello_world_17 { input:
    message = "Task 17",
    previous_message = read_string(hello_world_16.output_file)
  }

  call hello_world as hello_world_18 { input:
    message = "Task 18",
    previous_message = read_string(hello_world_17.output_file)
  }

  call hello_world as hello_world_19 { input:
    message = "Task 19",
    previous_message = read_string(hello_world_18.output_file)
  }

  call hello_world as hello_world_20 { input:
    message = "Task 20",
    previous_message = read_string(hello_world_19.output_file)
  }

  # Final summary task that combines all outputs
  call summarize { input:
    all_outputs = [
      hello_world_1.output_file,
      hello_world_2.output_file,
      hello_world_3.output_file,
      hello_world_4.output_file,
      hello_world_5.output_file,
      hello_world_6.output_file,
      hello_world_7.output_file,
      hello_world_8.output_file,
      hello_world_9.output_file,
      hello_world_10.output_file,
      hello_world_11.output_file,
      hello_world_12.output_file,
      hello_world_13.output_file,
      hello_world_14.output_file,
      hello_world_15.output_file,
      hello_world_16.output_file,
      hello_world_17.output_file,
      hello_world_18.output_file,
      hello_world_19.output_file,
      hello_world_20.output_file
    ]
  }

  output {
    Array[File] all_outputs = [
      hello_world_1.output_file,
      hello_world_2.output_file,
      hello_world_3.output_file,
      hello_world_4.output_file,
      hello_world_5.output_file,
      hello_world_6.output_file,
      hello_world_7.output_file,
      hello_world_8.output_file,
      hello_world_9.output_file,
      hello_world_10.output_file,
      hello_world_11.output_file,
      hello_world_12.output_file,
      hello_world_13.output_file,
      hello_world_14.output_file,
      hello_world_15.output_file,
      hello_world_16.output_file,
      hello_world_17.output_file,
      hello_world_18.output_file,
      hello_world_19.output_file,
      hello_world_20.output_file
    ]
    File summary = summarize.summary_file
  }
}

#### TASK DEFINITIONS ####

task hello_world {
  meta {
    description: "Simple hello world task that can be chained together"
    outputs: {
        output_file: "Text file containing the hello world message and timestamp"
    }
  }

  input {
    String message
    String previous_message
  }

  command <<<
    set -eo pipefail

    echo "============================================" > output.txt
    echo "Hello, World! - ~{message}" >> output.txt
    echo "Timestamp: $(date)" >> output.txt

    if [ -n "~{previous_message}" ]; then
      echo "" >> output.txt
      echo "Previous task said:" >> output.txt
      echo "~{previous_message}" >> output.txt
    fi

    echo "============================================" >> output.txt
  >>>

  output {
    File output_file = "output.txt"
  }

  runtime {
    docker: "ubuntu:20.04"
    cpu: 1
    memory: "1 GB"
  }
}

task summarize {
  meta {
    description: "Summarizes all the hello world outputs"
    outputs: {
        summary_file: "Combined summary file of all task outputs"
    }
  }

  input {
    Array[File] all_outputs
  }

  command <<<
    set -eo pipefail

    echo "========================================" > summary.txt
    echo "Hello World Chain - Summary Report" >> summary.txt
    echo "========================================" >> summary.txt
    echo "" >> summary.txt
    echo "Total tasks executed: ~{length(all_outputs)}" >> summary.txt
    echo "Generated at: $(date)" >> summary.txt
    echo "" >> summary.txt
    echo "All task outputs:" >> summary.txt
    echo "" >> summary.txt

    # Concatenate all outputs
    for file in ~{sep=' ' all_outputs}; do
      cat "$file" >> summary.txt
      echo "" >> summary.txt
    done

    echo "========================================" >> summary.txt
    echo "End of Summary" >> summary.txt
  >>>

  output {
    File summary_file = "summary.txt"
  }

  runtime {
    docker: "ubuntu:20.04"
    cpu: 1
    memory: "1 GB"
  }
}
