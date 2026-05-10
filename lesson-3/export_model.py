import torch
from torchvision import models

OUTPUT_PATH = "model.pt"


def main() -> None:
    model = models.mobilenet_v2(weights=models.MobileNet_V2_Weights.IMAGENET1K_V1)
    model.eval()

    example = torch.rand(1, 3, 224, 224)
    scripted = torch.jit.trace(model, example)
    scripted.save(OUTPUT_PATH)
    print(f"Saved TorchScript model to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()