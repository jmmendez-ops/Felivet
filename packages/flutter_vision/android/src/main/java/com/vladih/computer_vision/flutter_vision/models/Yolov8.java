package com.vladih.computer_vision.flutter_vision.models;

import android.content.Context;
import android.util.Log;

import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Vector;

public class Yolov8 extends Yolo {
    private static final String TAG = "Yolov8";

    public Yolov8(Context context,
                  String model_path,
                  boolean is_assets,
                  int num_threads,
                  boolean quantization,
                  boolean use_gpu,
                  String label_path,
                  int rotation) {
        super(context, model_path, is_assets, num_threads, quantization, use_gpu, label_path, rotation);
    }

    @Override
    public List<Map<String, Object>> detect_task(ByteBuffer byteBuffer,
                                                 int source_height,
                                                 int source_width,
                                                 float iou_threshold,
                                                 float conf_threshold,
                                                 float class_threshold) throws Exception {
        try {
            int[] input_shape = this.interpreter.getInputTensor(0).shape();
            this.interpreter.run(byteBuffer, this.output);
            //INFO: output from detection model is not normalized
            List<float[]> boxes = filter_box(this.output, iou_threshold, conf_threshold,
                    class_threshold, input_shape[1], input_shape[2]);
            boxes = restore_size(boxes, input_shape[1], input_shape[2], source_width, source_height);
            return out(boxes, this.labels);
        } catch (Exception e) {
            throw e;
        } finally {
            byteBuffer.clear();
        }
    }

    @Override
    protected List<float[]> filter_box(float[][][] model_outputs, float iou_threshold,
                                       float conf_threshold, float class_threshold, float input_width, float input_height) {
        try {
            List<float[]> pre_box = new ArrayList<>();
            int class_start_index = 4;
            int total_features = model_outputs[0].length;
            int total_detections = model_outputs[0][0].length;

            for (int i = 0; i < total_detections; i++) {
                float center_x = model_outputs[0][0][i];
                float center_y = model_outputs[0][1][i];
                float width = model_outputs[0][2][i];
                float height = model_outputs[0][3][i];

                float x1 = (center_x - width / 2f) * input_width;
                float y1 = (center_y - height / 2f) * input_height;
                float x2 = (center_x + width / 2f) * input_width;
                float y2 = (center_y + height / 2f) * input_height;

                int best_class_index = class_start_index;
                float best_confidence = model_outputs[0][best_class_index][i];

                for (int j = class_start_index + 1; j < total_features; j++) {
                    float current = model_outputs[0][j][i];
                    if (current > best_confidence) {
                        best_confidence = current;
                        best_class_index = j;
                    }
                }

                Log.d(TAG, String.format("Candidate %d: raw max class score=%.6f, class=%d",
                        i, best_confidence, best_class_index - class_start_index));

                if (best_confidence > class_threshold) {
                    float[] tmp = new float[6];
                    tmp[0] = Math.max(0, x1);
                    tmp[1] = Math.max(0, y1);
                    tmp[2] = x2;
                    tmp[3] = y2;
                    tmp[4] = best_confidence;
                    tmp[5] = (best_class_index - class_start_index) * 1f;
                    pre_box.add(tmp);
                }
            }
            if (pre_box.isEmpty()) return new ArrayList<>();
            //for reverse orden, insteand of using .reversed method
            Comparator<float[]> compareValues = (v1, v2) -> Float.compare(v2[4], v1[4]);
            //Collections.sort(pre_box,compareValues.reversed());
            Collections.sort(pre_box, compareValues);
            return nms(pre_box, iou_threshold);
        } catch (Exception e) {
            throw e;
        }
    }

    @Override
    protected List<Map<String, Object>> out(List<float[]> yolo_result, Vector<String> labels) {
        try {
            List<Map<String, Object>> result = new ArrayList<>();
            for (float[] box : yolo_result) {
                Map<String, Object> output = new HashMap<>();
                output.put("box", new float[]{box[0], box[1], box[2], box[3], box[4]}); //x1,y1,x2,y2,conf_class
                output.put("tag", labels.get((int) box[5]));
                result.add(output);
            }
            return result;
        } catch (Exception e) {
            throw e;
        }
    }
}
