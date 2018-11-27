# EDA Simulator to test Filer Performance

This EDA Simulator helps test filer performance.  The simulator has 4 components:
 1. **jobsubmitter** - the task that submits job config files for processing
 1. **orchestrator** - the task the reads the job config files and writes workstart files, and submits work to workers for processing.  This also receives completed jobs from workers, writes a job complete file, and submits a job for upload.
 1. **worker** - the task that takes a workitem, reads the start files, and writes the complete files and or error file depending on error probability. 
 1. **uploader** - this task receives upload tasks for each completed job, and reads all job config files and job work files.

The job uses Azure Storage Queue for work management, and uses event hub for measuring file statistics.  The goal of the EDA simulator is to test with various filers to understand the filer performance characteristics.

The four components above implement the following message sequence chart:

![Message sequence chart for the job dispatch](../../../../docs/images/edasim/msc.png)