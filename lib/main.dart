import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

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

  /// Select an image via gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    File selected = await ImagePicker.pickImage(source: source);

    setState(() {
      _imageFile = selected;
    });
  }

  /// Cropper plugin
  Future<void> _cropImage() async {
    File cropped = await ImageCropper.cropImage(
        sourcePath: _imageFile.path
    );

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
             onPressed: () => _pickImage(ImageSource.camera),
           ),
           IconButton(
             icon: Icon(Icons.photo_library),
             onPressed: () => _pickImage(ImageSource.gallery),
           )
         ],
       ),
     ),
      body: ListView(
        children: <Widget>[
          if(_imageFile !=null) ...[
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
  final FirebaseStorage _storage = FirebaseStorage(storageBucket: 'gs://flutterquotesapp.appspot.com/');

  StorageUploadTask _uploadTask;

  void _startUpload() {
      String filePath = 'images/${DateTime.now()}.png';

      setState(() {
        _uploadTask = _storage.ref().child(filePath).putFile(widget.file);
      });
  }

  @override
  Widget build(BuildContext context) {
    if ( _uploadTask != null) {
      return StreamBuilder<StorageTaskEvent>(
        stream: _uploadTask.events,
        builder: (context, snapshot) {
          var event = snapshot?.data?.snapshot;

          double progressPercent = event != null ? event.bytesTransferred / event.totalByteCount:0;

          return Column(
            children: <Widget>[
              if(_uploadTask.isComplete)
                Text('Uploaded!'),
              if(_uploadTask.isPaused)
                FlatButton(child: Icon(Icons.play_arrow),
                onPressed: _uploadTask.resume,),
              if(_uploadTask.isInProgress)
                FlatButton(child: Icon(Icons.pause),onPressed: _uploadTask.pause,),
              LinearProgressIndicator(value: progressPercent),
              Text(
                '${(progressPercent * 100).toStringAsFixed(2)} % '
              )
            ],
          );
        });
    } else {
      return FlatButton.icon(onPressed: _startUpload, icon: Icon(Icons.cloud_upload), label: Text('Upload to Firebase'));
    }

    return Container();
  }
}

