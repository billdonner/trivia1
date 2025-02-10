<?php
// Set the content type to JSON
header('Content-Type: application/json');

// Scan the current directory
$files = scandir(__DIR__);

// Filter out only JSON files (ignoring directories)
$jsonFiles = array();
foreach ($files as $file) {
    if (is_file(__DIR__ . '/' . $file) && strtolower(pathinfo($file, PATHINFO_EXTENSION)) === 'json') {
        $jsonFiles[] = $file;
    }
}

// Output the JSON-encoded array of filenames
echo json_encode($jsonFiles);
?>
