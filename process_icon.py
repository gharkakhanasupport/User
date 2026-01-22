
import numpy as np
from PIL import Image

def process_icon():
    # Load the generated image
    input_path = "C:/Users/adity/.gemini/antigravity/brain/a5a206a5-514c-4adc-a886-a78d675e4054/notification_icon_source_1768160534547.png"
    output_path = "C:/Users/adity/OneDrive/Desktop/ALL/GKK/USER/android/app/src/main/res/drawable/ic_notification.png"
    
    # Open image using PIL
    img = Image.open(input_path).convert("RGBA")
    data = img.getdata()
    
    newData = []
    for item in data:
        # Check if the pixel is black (or close to black)
        if item[0] < 50 and item[1] < 50 and item[2] < 50:
            # keying out black
            newData.append((255, 255, 255, 0))
        else:
            # keeping white pixels, creating outline
            newData.append((255, 255, 255, 255))
            
    img.putdata(newData)
    
    # Resize to standard notification icon size (e.g. 48x48 or 96x96 for higher density)
    # Keeping it reasonably high res (96) so Android downscales nicely
    img = img.resize((96, 96), Image.Resampling.LANCZOS)
    
    img.save(output_path, "PNG")
    print(f"Icon saved to {output_path}")

if __name__ == "__main__":
    process_icon()
