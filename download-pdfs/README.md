# Download PDFs

Scan through all of the Assembla tickets as listed in `data/tickets.data.js` file and either:

* Download the PDF by clicking on the appropriate button, or
* Make a screenshot of the page and place it in the `screenshots` directory.

## Install and run

```
$ cd download-pdfs
$ npm install
$ cypress run
```

## Trouble-shooting

Depending on how large the list of tickets is, the script may choke after awhile. Just comment out the tickets which have already been processed and restart.
