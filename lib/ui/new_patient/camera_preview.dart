import 'package:camera/camera.dart';
import 'package:eye_capture/constants/numbers.dart';
import 'package:eye_capture/constants/strings.dart';
import 'package:eye_capture/ui/new_patient/image_preview.dart';
import 'package:eye_capture/ui/new_patient/new_patient_bloc.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class LiveCameraPreview extends StatefulWidget {
  final NewPatientBloc newPatientBloc;

  const LiveCameraPreview({Key key, this.newPatientBloc}) : super(key: key);

  @override
  _LiveCameraPreviewState createState() => _LiveCameraPreviewState();
}

class _LiveCameraPreviewState extends State<LiveCameraPreview> {
  bool isFlashOn;
  bool hasFlashLight;
  List<String> eyes = [LEFT_EYE, RIGHT_EYE];
  List<String> camEyes = [CAM_LEFT_EYE, CAM_RIGHT_EYE];
  int eyeSelector;
  double scale;
  CameraController controller;
  List cameras;
  int selectedCameraIdx;
  String imagePath;
  bool _isLoading;

  @override
  void initState() {
    super.initState();
    isFlashOn = false;
    _isLoading = false;
    scale = 3.0;
    eyeSelector = 0;
    initCamera();
  }

  @override
  void dispose() {
    super.dispose();
    controller?.dispose();
  }

  initCamera() {
    availableCameras().then((availableCameras) {
      cameras = availableCameras;
      if (cameras.length > 0) {
        setState(() {
          selectedCameraIdx = 0;
        });

        _initCameraController(cameras[selectedCameraIdx]).then((void v) {});
      } else {
        print("No camera available");
      }
    }).catchError((err) {
      print('Error: $err.code\nError Message: $err.message');
    });
  }

  Future _initCameraController(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller.dispose();
    }

    controller = CameraController(cameraDescription, ResolutionPreset.max);
    controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
      if (controller.value.hasError) {
        print('Camera error ${controller.value.errorDescription}');
      }
    });
    try {
      await controller.initialize();
      hasFlashLight = await controller.hasFlash;
    } on CameraException catch (e) {
      _showCameraException(e);
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _showCameraException(CameraException e) {
    String errorText = 'Error: ${e.code}\nError Message: ${e.description}';
    print(errorText);

    print('Error: ${e.code}\n${e.description}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(CAMERA_PREVIEW_APPBAR),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              flex: 1,
              child: _cameraPreviewWidget(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _getBottomAppBar(context),
    );
  }

  BottomAppBar _getBottomAppBar(BuildContext context) {
    return BottomAppBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _getSliderController(),
          SizedBox(height: 10.0),
          _getCaptureImageRow(context),
          SizedBox(height: 20.0),
        ],
      ),
    );
  }

  Row _getCaptureImageRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        _eyeToggleRowWidget(),
        _captureControlRowWidget(context),
        _flashToggleRowWidget(),
        //Spacer(),
      ],
    );
  }

  Widget _cameraPreviewWidget() {
    if (controller == null || !controller.value.isInitialized || _isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 10.0),
            Text(
              "Processing image, please wait...",
              style: TextStyle(
                fontSize: REGULAR_FONT_SIZE,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: <Widget>[
        Transform.scale(
          scale: scale,
          child: RotatedBox(
            quarterTurns: 2,
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: CameraPreview(controller),
              ),
            ),
          ),
        ),
        Container(
          margin: EdgeInsets.all(PAGE_PADDING),
          decoration: new BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              width: 3.0,
              color: Colors.blueGrey,
            ),
          ),
        ),
      ],
    );
  }

  Row _getSliderController() {
    return Row(
      children: <Widget>[
        Expanded(
          child: Slider(
            activeColor: Colors.blue,
            min: 1.0,
            max: 3.0,
            divisions: 20,
            value: scale,
            onChanged: (value) {
              setState(() {
                scale = value;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 5.0, right: 20.0),
          child: Text("${double.parse(scale.toStringAsFixed(2))} X"),
        ),
      ],
    );
  }

  Widget _flashToggleRowWidget() {
    return Expanded(
      child: Align(
        alignment: Alignment.centerRight,
        child: FlatButton.icon(
          onPressed: () {
            print("Flash mode switched");
            _toggleFlash();
          },
          icon: isFlashOn ? Icon(Icons.flash_on) : Icon(Icons.flash_off),
          label: isFlashOn ? Text("On") : Text("Off"),
        ),
      ),
    );
  }

  _toggleFlash() async {
    if(hasFlashLight && !isFlashOn) {
      await controller.flashOn();
      setState(() {
        isFlashOn = !isFlashOn;
      });
    } else {
      await controller.flashOff();
      setState(() {
        isFlashOn = false;
      });
    }
  }

  Widget _eyeToggleRowWidget() {
    return Expanded(
      child: Align(
        alignment: Alignment.centerLeft,
        child: FlatButton.icon(
          onPressed: () {
            print("Eye mode switched");
            setState(() {
              eyeSelector = (eyeSelector + 1) % 2;
            });
          },
          icon: Icon(Icons.remove_red_eye),
          label: Text(camEyes[eyeSelector]),
        ),
      ),
    );
  }

  Widget _captureControlRowWidget(context) {
    return Expanded(
      child: Align(
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          mainAxisSize: MainAxisSize.max,
          children: [
            FloatingActionButton(
              child: Icon(Icons.camera),
              backgroundColor: Colors.blueGrey,
              onPressed: () {
                _onCapturePressed(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onCapturePressed(context) async {
    print("Capture Button Pressed");
    setState(() {
      _isLoading = true;
    });
    try {
      String dateTime = DateTime.now().toString();
      final path = join(
        (await getExternalStorageDirectory()).path,
        '${dateTime.replaceAll(" ", "_").substring(0, 19)}.png',
      );
      debugPrint(
          "$path - $dateTime - ${eyes[eyeSelector]} - ${scale.toString()}");
      await controller.takePicture(path);

      await controller.flashOff();
      setState(() {
        isFlashOn = false;
        _isLoading = false;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImagePreviewWithButton(
            imagePath: path,
            dateTime: dateTime,
            eyeDescription: eyes[eyeSelector],
            zoomLevel: scale,
            newPatientBloc: widget.newPatientBloc,
          ),
        ),
      );
    } catch (e) {
      print(e);
    }
  }
}
