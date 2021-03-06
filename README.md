Cruiser is a lightweight continuous build integration server written in Powershell. Cruiser can detect changes in your source control repository and trigger a build process.

Supports Mercurial & Git as source control repositories, along with a simple file system source.

# Quick Start

##1. Install Cruiser 

Paste the following line at the powershell prompt.

`
(new-object Net.WebClient).DownloadString("https://bitbucket.org/TechHike/cruiser/raw/default/Install.ps1") | iex
`

This will download all the necessary Cruiser files and import the cruiser module. When the process is finished, you should see a message that says: "Cruiser initialize."

##2. Initialize a working directory

The working directory is where Cruiser places assets such as state files, history, source files and output files.

Create a new directory, then change directory into the your new directory. Paste the following line into the powershell prompt.

`
Initialize-Cruiser
`

This will create directories and files that are necessary for Cruiser to operate. You will see that the Cruiser-Config.ps1 file will pop open. Read more about configuring cruiser later, let's create our first build now.

##3. Start Cruiser

At the powershell prompt, paste:

`
Start-Cruiser
`

This will kick off a build of the Cruiser project hosted on Bitbucket. You will see a number of new files and directories under your working directory.

Take a look under the output directory and you'll see the build output directory (Cruiser_1.0.1). You will also see index.html at the output root. Open index.html to see the build history displayed in your browser.

##4. Start Cruiser as a Server

Paste this into the powershell prompt:

`
Start-Cruiser -Server
`

This will start Cruiser in server mode. The same build process happens, but it will wait for 5 minutes (by default) between polls.

##5. Start Cruiser in the background

Type:

`
Start-Cruiser -Background -Server
`

Now Cruiser will run in the background as a server. Common job commands are available:

`
Receive-Cruiser
Stop-Cruiser
`


If you would like to use Cruiser from any powershell prompt, you will need to import the Cruiser module as a part of your powershell profile script. Like this:

`
Import-Module Cruiser
`
