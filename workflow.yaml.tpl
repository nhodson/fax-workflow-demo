# This workflow does the following:
# - makes a call to Doc AI OCR processor for the input file
# - parses Doc AI output location
# - creates a callback for human review of parsed document
# - posts result to HTTP endpoint
main:
  params: [event]
  steps:
    - batch_process:
        call: googleapis.documentai.v1.projects.locations.processors.batchProcess
        args:
          name: "projects/${projectId}/locations/us/processors/${processorId}"
          location: "us"
          body:
            inputDocuments:
              gcsDocuments:
                documents:
                - gcsUri: $${"gs://" + event.data.bucket + "/" + event.data.name}
                  mimeType: "application/pdf"
            documentOutputConfig:
              gcsOutputConfig:
                gcsUri: "gs://${projectId}-docai-output/"
        result: batch_process_resp
    - get_output_path:
        call: text.find_all_regex
        args:
          source: $${batch_process_resp.metadata.individualProcessStatuses[0].outputGcsDestination}
          regexp: "[\d]*/[\d]*$"
        result: ocr_output_prefix
    - list_ocr_objects:
        call: googleapis.storage.v1.objects.list
        args:
          bucket: "${projectId}-docai-output"
          prefix: $${ocr_output_prefix[0].match}
        result: ocr_objects
    - create_callback:
        call: events.create_callback_endpoint
        args:
            http_callback_method: "GET"
        result: callback_details
    - print_callback_details:
        call: sys.log
        args:
            severity: "INFO"
            text: $${"Listening for callbacks on " + callback_details.url}
    - await_callback:
        call: events.await_callback
        args:
            callback: $${callback_details}
            timeout: 3600
        result: callback_request
    - post_result:
        call: http.post
        args:
          url: "https://postman-echo.com/post"
          body:
            message: "This is expected to be sent back in response."
        result: document_content
    - return:
        return: $${document_content}