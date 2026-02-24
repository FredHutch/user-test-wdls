version 1.0

workflow HelloWorkflow {
    input {
        String name
        String greeting = "Hello"
        Int repeat_count = 1
    }

    call SayHello {
        input:
            name = name,
            greeting = greeting,
            repeat_count = repeat_count
    }

    call CountCharacters {
        input:
            message = SayHello.message
    }

    output {
        String message = SayHello.message
        File message_file = SayHello.message_file
        Int character_count = CountCharacters.count
    }

    meta {
        description: "A simple, self-contained WDL 1.0 workflow that greets someone and counts the characters in the greeting."
        author: "test"
    }
}

task SayHello {
    input {
        String name
        String greeting
        Int repeat_count
    }

    String full_message = "~{greeting}, ~{name}!"

    command <<<
        for i in $(seq 1 ~{repeat_count}); do
            echo "~{full_message}"
        done
        echo "~{full_message}" > message.txt
    >>>

    output {
        String message = full_message
        File message_file = "message.txt"
    }

    runtime {
        docker: "ubuntu:22.04"
    }
}

task CountCharacters {
    input {
        String message
    }

    command <<<
        echo -n "~{message}" | wc -c | tr -d ' '
    >>>

    output {
        Int count = read_int(stdout())
    }

    runtime {
        docker: "ubuntu:22.04"
    }
}