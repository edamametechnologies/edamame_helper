# edamame_helper
This is the Helper application for the EDAMAME Security application. 
It's used to execute security checks, remediation and rollback actions that require elevated privileges beyond the application sandboxed environment.
All the actions performed through the Helper strictly follow the threat models defined in the threat model repo (https://github.com/edamametechnologies/threatmodels).
The Helper relies on edamame_foundation, an open source library that contains the foundation for EDAMAME threat management (https://github.com/edamametechnologies/edamame_foundation).