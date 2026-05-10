import argparse
from pathlib import Path

import torch
from PIL import Image

HERE = Path(__file__).resolve().parent
MODEL_PATH = HERE / "model.pt"
LABELS_PATH = HERE / "imagenet_classes.txt"

IMAGENET_MEAN = torch.tensor([0.485, 0.456, 0.406]).view(3, 1, 1)
IMAGENET_STD = torch.tensor([0.229, 0.224, 0.225]).view(3, 1, 1)


def preprocess(image_path: Path) -> torch.Tensor:
    img = Image.open(image_path).convert("RGB")

    w, h = img.size
    scale = 256 / min(w, h)
    img = img.resize((round(w * scale), round(h * scale)), Image.BILINEAR)

    w, h = img.size
    left = (w - 224) // 2
    top = (h - 224) // 2
    img = img.crop((left, top, left + 224, top + 224))

    tensor = torch.frombuffer(bytearray(img.tobytes()), dtype=torch.uint8)
    tensor = tensor.view(224, 224, 3).permute(2, 0, 1).float().div_(255.0)
    tensor = (tensor - IMAGENET_MEAN) / IMAGENET_STD
    return tensor.unsqueeze(0)


def load_labels() -> list[str]:
    with LABELS_PATH.open() as f:
        return [line.strip() for line in f if line.strip()]


def main() -> None:
    parser = argparse.ArgumentParser(description="MobileNetV2 TorchScript inference")
    parser.add_argument("image", type=Path, help="Path to input image")
    parser.add_argument("--top-k", type=int, default=3)
    args = parser.parse_args()

    model = torch.jit.load(str(MODEL_PATH), map_location="cpu")
    model.eval()
    labels = load_labels()

    with torch.no_grad():
        logits = model(preprocess(args.image))
        probs = torch.softmax(logits[0], dim=0)
        top = torch.topk(probs, args.top_k)

    print(f"Top-{args.top_k} predictions for {args.image.name}:")
    for rank, (score, idx) in enumerate(zip(top.values.tolist(), top.indices.tolist()), 1):
        print(f"  {rank}. {labels[idx]:<40s}  {score:.4f}")


if __name__ == "__main__":
    main()