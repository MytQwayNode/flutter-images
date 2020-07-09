import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: ImageCapture(),
    );
  }
}

class ImageCapture extends StatefulWidget {
  @override
  _ImageCaptureState createState() => _ImageCaptureState();
}

class _ImageCaptureState extends State<ImageCapture> {
  /// Active image file
  File _imageFile;
  final picker = ImagePicker();

  /// Select an image via gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    PickedFile selected =
        await picker.getImage(source: source, maxHeight: 240, maxWidth: 320);

    setState(() {
      _imageFile = File(selected.path);
    });
  }

  /// Cropper plugin
  Future<void> _cropImage() async {
    File cropped = await ImageCropper.cropImage(sourcePath: _imageFile.path);

    setState(() {
      _imageFile = cropped ?? _imageFile;
    });
  }

  /// Remove image
  void _clear() {
    setState(() {
      _imageFile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomAppBar(
        child: Row(
          children: <Widget>[
            IconButton(
              icon: Icon(Icons.photo_camera),
              onPressed: () {
                _clear();
                return _pickImage(ImageSource.camera);
              },
            ),
            IconButton(
              icon: Icon(Icons.photo_library),
              onPressed: () {
                _clear();
                return _pickImage(ImageSource.gallery);
              },
            )
          ],
        ),
      ),
      body: ListView(
        children: <Widget>[
          if (_imageFile != null) ...[
            Image.file(_imageFile),
            Row(
              children: <Widget>[
                FlatButton(
                  child: Icon(Icons.crop),
                  onPressed: _cropImage,
                ),
                FlatButton(
                  child: Icon(Icons.refresh),
                  onPressed: _clear,
                )
              ],
            ),
            Uploader(file: _imageFile)
          ]
        ],
      ),
    );
  }
}

class Uploader extends StatefulWidget {
  final File file;

  const Uploader({Key key, this.file}) : super(key: key);
  @override
  _UploaderState createState() => _UploaderState();
}

class _UploaderState extends State<Uploader> {
  final FirebaseStorage _storage =
      FirebaseStorage(storageBucket: 'gs://flutterquotesapp.appspot.com/');

  StorageUploadTask _uploadTask;

  String dropdownValue;
  List<String> _categories = [];
  TextEditingController filenameInputController = TextEditingController();
  String filename;

  void _startUpload() async {
    String filePath = 'images/$dropdownValue/{DateTime.now()}.png';

    setState(() {
      _uploadTask = _storage.ref().child(filePath).putFile(widget.file);
    });

    var storageTaskSnapshot = await _uploadTask.onComplete;
    var downloadUrl = await storageTaskSnapshot.ref.getDownloadURL();
    debugPrint(downloadUrl);
    Firestore.instance.collection("images").add({
      "category": dropdownValue,
      "name": filename,
      "imageUrl": downloadUrl
    }).then((response) {
      print(response.documentID);
    }).catchError((error) {
      print(error);
    });
  }

  @override
  void initState() {
    /// TEST ENUM based FIRESTORE
    super.initState();

    Firestore.instance
        .collection("dropdownList")
        .document("category")
        .get()
        .then((value) {
      setState(() {
        value.data["list"].forEach((element) {
          _categories.add(element.toString());
          print(element);
        });
      });
    });

    filenameInputController.addListener(() {
      setState(() {
        filename = filenameInputController.text;
      });
    });
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is removed from the widget tree.
    // This also removes the _printLatestValue listener.
    filenameInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_uploadTask != null) {
      return StreamBuilder<StorageTaskEvent>(
          stream: _uploadTask.events,
          builder: (context, snapshot) {
            var event = snapshot?.data?.snapshot;

            double progressPercent = event != null
                ? event.bytesTransferred / event.totalByteCount
                : 0;

            return Column(
              children: <Widget>[
                if (_uploadTask.isComplete) Text('Uploaded!'),
                if (_uploadTask.isPaused)
                  FlatButton(
                    child: Icon(Icons.play_arrow),
                    onPressed: _uploadTask.resume,
                  ),
                if (_uploadTask.isInProgress)
                  FlatButton(
                    child: Icon(Icons.pause),
                    onPressed: _uploadTask.pause,
                  ),
                LinearProgressIndicator(value: progressPercent),
                Text('${(progressPercent * 100).toStringAsFixed(2)} % ')
              ],
            );
          });
    } else {
      return Container(
          child: Column(
        children: <Widget>[
          DropdownButton(
            hint: Text("Please choose a category"),
            value: dropdownValue,
            items: _categories.map((location) {
              return DropdownMenuItem(
                child: new Text(location),
                value: location,
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                dropdownValue = newValue;
              });
              debugPrint(dropdownValue);
            },
          ),
          TextField(
            controller: filenameInputController,
            decoration: InputDecoration(
              labelText: "Filename:",
            ),
          ),
          if (dropdownValue != null && filename!="")
            FlatButton.icon(
                onPressed: _startUpload,
                icon: Icon(Icons.cloud_upload),
                label: Text('Upload to Firebase')),
        ],
      ));
    }

    return Container();
  }
}
