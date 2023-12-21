# langfuse-initialization
Basic Repo with shell script to initialize langfuse + relevant patterns


# Langfuse Docker Setup Script

This script automates the process of setting up Langfuse and a PostgreSQL database using Docker. It checks for and installs Docker and OpenSSL if they are not present, generates high-entropy secrets for secure operation, and allows for flexible configuration through either command-line arguments or a YAML file.

## Requirements

-   A Unix-like operating system (e.g., Linux, macOS)
-   `docker` and `docker-compose` installed
-   `openssl` for generating secrets
-   `yq` for YAML parsing (optional, required only if using YAML for configuration)
-   Internet access for pulling Docker images
-   Sudo privileges (for installing Docker and OpenSSL if not already installed)

## Installation

1.  **Install `yq` for YAML parsing (Optional):**
    
    If you plan to use a YAML configuration file, install `yq` using pip:
    
    bashCopy code
    
    `pip install yq` 
    
2.  **Download the Script:**
    
    Download the `setup_langfuse.sh` script to your desired directory.
    
3.  **Make the Script Executable:**
    
    Navigate to the directory containing the script and make it executable:
    
    bashCopy code
    
    `chmod +x setup_langfuse.sh` 
    

## Usage

You can run the script either by passing command-line arguments directly or by using a YAML configuration file.

### Using Command-Line Arguments:

Provide the necessary configuration details directly as arguments:

`./setup_langfuse.sh [POSTGRES_USER] [POSTGRES_PASSWORD] [POSTGRES_DB] [POSTGRES_PORT] [LANGFUSE_HOST] [NEXTAUTH_URL]` 

Replace the bracketed terms with your actual PostgreSQL and Langfuse configuration values.

### Using a YAML Configuration File:

Create a YAML file (e.g., `config.yaml`) with the following format:

    postgres:
      user: <user>
      password: <password>
      dbname: <dbname>
      port: <port>
    
    langfuse:
      host: <host>
      nextauth_url: http://localhost:3000

Run the script without arguments, and when prompted, provide the path to your YAML configuration file:

`./setup_langfuse.sh` 

## Script Actions

The script performs the following actions:

1.  Checks for and installs Docker and OpenSSL if they are not present.
2.  Generates high-entropy secrets for `NEXTAUTH_SECRET` and `SALT`.
3.  Pulls the latest Docker images for PostgreSQL and Langfuse.
4.  Starts the PostgreSQL container with persistent storage.
5.  Starts the Langfuse container linked to the PostgreSQL database.

----
----
----


# Langfuse Docker Teardown Script

This script is designed to safely stop and remove Docker containers associated with the Langfuse application and its PostgreSQL database. It provides a convenient way to clean up your environment after running Langfuse.

## Requirements

-   Docker must be installed on your system.
-   The script should be run on the machine where the Langfuse and PostgreSQL Docker containers are running.

## Installation

1.  **Download the Script:**
    
    Download the `langfuse_teardown.sh` script to your desired directory.
    
2.  **Make the Script Executable:**
    
    Navigate to the directory containing the script and make it executable:
    
    bashCopy code
    
    `chmod +x langfuse_teardown.sh` 
    

## Usage

Run the script to stop and remove the Docker containers:

`./langfuse_teardown.sh` 

## Script Actions

The script performs the following actions:

1.  Stops the `langfuse` and `postgres-langfuse` Docker containers.
2.  Removes the `langfuse` and `postgres-langfuse` Docker containers.

### Optional Cleanup Actions:

The script also includes optional commands (commented out by default) to:

-   Remove the Docker images (`ghcr.io/langfuse/langfuse:latest` and `postgres`).
-   Remove the Docker volume (`postgres-langfuse-data`) used for the PostgreSQL database.

**Warning:** Uncommenting and running these optional commands will remove the downloaded Docker images and delete the database data stored in the Docker volume. Use these options only if you want a complete cleanup and do not need the data or images anymore.