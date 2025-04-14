from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
from ultralytics import YOLO
import cv2
import numpy as np
import ast
import base64

app = FastAPI()
model = YOLO("best.pt")  # ✅ Path to your trained model

@app.post("/detect/")
async def detect_image(file: UploadFile = File(...)):
    contents = await file.read()
    npimg = np.frombuffer(contents, np.uint8)
    image = cv2.imdecode(npimg, cv2.IMREAD_COLOR)

    best_result = None
    for conf_threshold in [0.7, 0.5, 0.3, 0.2, 0.1]:
        results = model.predict(source=image, conf=conf_threshold, save=False)
        r = results[0]
        if len(r.boxes) > 0:
            best_result = r
            print(f"✅ Detected at conf: {conf_threshold}")
            break

    if best_result is None:
        print("⚠️ Using fallback confidence = 0.05")
        results = model.predict(source=image, conf=0.05, save=False)
        best_result = results[0]

    r = best_result
    if not r.boxes:
        print("❌ No boxes detected at all.")
        return JSONResponse(content={"disease": "unknown", "image": None})

    # Get label
    cls = int(r.boxes.cls[0])
    label_string = str(model.names[cls])
    label_dict = ast.literal_eval(label_string)
    label_name = list(label_dict.values())[0]
    print(f"🧠 Label Name: {label_name}")

    # Draw detections
    for box, cls_id, conf in zip(r.boxes.xyxy, r.boxes.cls, r.boxes.conf):
        x1, y1, x2, y2 = map(int, box)
        text = label_name
        cv2.rectangle(image, (x1, y1), (x2, y2), (0, 255, 0), 2)
        (tw, th), baseline = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, 0.7, 2)
        cv2.rectangle(image, (x1, y1 - th - baseline), (x1 + tw, y1), (0, 255, 0), -1)
        cv2.putText(image, text, (x1, y1 - 5), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 0), 2)

    print("🖼️ Drawing complete. Encoding image...")

    # Encode
    success, img_encoded = cv2.imencode('.jpg', image)
    if not success:
        print("❌ cv2 failed to encode image.")
        return JSONResponse(content={"disease": label_name, "image": None})

    img_base64 = base64.b64encode(img_encoded).decode('utf-8')
    print(f"✅ Image encoded. Length: {len(img_base64)}")

    return JSONResponse(content={
        "disease": label_name,
        "image": img_base64
    })
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

#I USED THIS FOR TESTING YA SHEIK!!! DONT UNCOMMENT

# import requests
#
# image_path = r'D:\android projects\Grad_proj\backend\CANCER.jpg'
# url = 'http://127.0.0.1:8000/detect/'
#
# with open(image_path, 'rb') as f:
#     files = {'file': f}
#     response = requests.post(url, files=files)
#
# data = response.json()
# print("✅ Disease Detected:", data.get('disease'))
#
# # Safely check for image key
# img_base64 = data.get('image')
# if img_base64:
#     print("📸 Image Base64 Length:", len(img_base64))
# else:
#     print("⚠️ No image returned.")
