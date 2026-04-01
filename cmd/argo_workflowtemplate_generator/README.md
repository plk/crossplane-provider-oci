# Argo Workflow Template Generator

The Argo Workflow Template Generator is a tool used to generate Argo workflow templates for Crossplane providers.

## Usage

To use the Workflow Generator, run the following command:

```bash
go run main.go <version>
```

Replace `<version>` with the desired version of the Crossplane provider.

## Directory Structure

The Workflow Generator expects the following directory structure:

* `examples/`: contains example resource files for the Crossplane provider
* `argo-auto/`: generated Argo workflow templates will be written to this directory

## How it Works

1. The Workflow Generator reads the contents of the `examples/` directory and processes each service version found.
2. For each service version, it generates a workflow template file using the template in `templates/workflowtemplate.yaml.tmpl`.
3. The generated workflow template files are written to the `argo-auto/` directory.

## Notes

* The Workflow Generator uses the `version` command-line argument to determine which version of the Crossplane provider to generate workflow templates for.
* The `examples/` directory should contain subdirectories for each service, with subdirectories for each version.
* The `templates/workflowtemplate.yaml.tmpl` file should contain the template for generating Argo workflow templates.