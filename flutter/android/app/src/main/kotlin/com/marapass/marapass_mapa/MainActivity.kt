package com.marapass.marapass_mapa
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.content.Context
import android.view.Surface

class MainActivity : FlutterActivity() {
 override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
  super.configureFlutterEngine(flutterEngine)
  val sensors=getSystemService(Context.SENSOR_SERVICE) as SensorManager
  val sensor=sensors.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
  var listener: SensorEventListener?=null
  EventChannel(flutterEngine.dartExecutor.binaryMessenger,"marapass/compass").setStreamHandler(object:EventChannel.StreamHandler {
   override fun onListen(arguments:Any?,events:EventChannel.EventSink){
    if(sensor==null){events.error("unavailable","Bússola indisponível",null);return}
    listener=object:SensorEventListener {
     private var previous=0L
     override fun onSensorChanged(event:SensorEvent){
      if(event.accuracy==SensorManager.SENSOR_STATUS_UNRELIABLE || event.timestamp-previous<100000000L)return
      previous=event.timestamp
      val matrix=FloatArray(9);val orientation=FloatArray(3)
      SensorManager.getRotationMatrixFromVector(matrix,event.values)
      val remapped=FloatArray(9)
      @Suppress("DEPRECATION")
      val rotation=windowManager.defaultDisplay.rotation
      val axisX=when(rotation){Surface.ROTATION_90->SensorManager.AXIS_Y;Surface.ROTATION_180->SensorManager.AXIS_MINUS_X;Surface.ROTATION_270->SensorManager.AXIS_MINUS_Y;else->SensorManager.AXIS_X}
      val axisY=when(rotation){Surface.ROTATION_90->SensorManager.AXIS_MINUS_X;Surface.ROTATION_180->SensorManager.AXIS_MINUS_Y;Surface.ROTATION_270->SensorManager.AXIS_X;else->SensorManager.AXIS_Y}
      SensorManager.remapCoordinateSystem(matrix,axisX,axisY,remapped)
      SensorManager.getOrientation(remapped,orientation)
      events.success((Math.toDegrees(orientation[0].toDouble())+360.0)%360.0)
     }
     override fun onAccuracyChanged(sensor:Sensor?,accuracy:Int){}
    }
    listener?.let { sensors.registerListener(it,sensor,SensorManager.SENSOR_DELAY_UI) }
   }
   override fun onCancel(arguments:Any?){listener?.let { sensors.unregisterListener(it) };listener=null}
  })
 }
}
