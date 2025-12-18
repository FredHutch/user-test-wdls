version 1.0

workflow ThousandQuickTasks {
  input {
    String prefix = "task"
  }

  scatter (i in range(1000)) {
    call QuickTask { input: task_id = i, prefix = prefix }
  }

  output {
    Array[String] results = QuickTask.result
  }
}

task QuickTask {
  input {
    Int task_id
    String prefix
  }

  command <<<
    echo "~{prefix}_~{task_id}: completed at $(date)"
  >>>

  output {
    String result = read_string(stdout())
  }

  runtime {
    docker: "ubuntu:20.04"
    memory: "128 MB"
    cpu: 1
    disks: "local-disk 1 HDD"
  }
}
