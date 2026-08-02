#!/usr/bin/env python3
"""Generator syntetycznego, wielostronicowego dokumentu rastrowego dla E1-13.

Dokument nie ma warstwy tekstowej, więc wymusza pełne OCR. Liczba stron jest
parametrem, bo próba E1-13 potrzebuje przetwarzania na tyle długiego, żeby
zdążyć potwierdzić stan `started` i wykonać kontrolowany restart.

Materiał jest w całości syntetyczny. Nie jest skanem rzeczywistej kartki i nie
zamyka wymagania reprezentatywności z `01-test-document-manifest.md`.

Uruchamiać w kontenerze Paperless — tam są Pillow, img2pdf i czcionki.
"""
import argparse
import hashlib
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

# Obraz 3.0.4 nie zawiera DejaVu, tylko zestaw URW base35. Wybieramy pierwszy
# dostępny wariant, żeby generator działał w kontenerze bez dokładania pakietów.
FONT_CANDIDATES = {
    "serif": [
        "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf",
        "/usr/share/fonts/opentype/urw-base35/NimbusRoman-Regular.otf",
        "/usr/share/fonts/opentype/urw-base35/P052-Roman.otf",
    ],
    "serif_bold": [
        "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf",
        "/usr/share/fonts/opentype/urw-base35/NimbusRoman-Bold.otf",
        "/usr/share/fonts/opentype/urw-base35/P052-Bold.otf",
    ],
    "sans": [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/opentype/urw-base35/NimbusSans-Regular.otf",
        "/usr/share/fonts/opentype/urw-base35/URWGothic-Book.otf",
    ],
}


def pick_font(kind):
    for path in FONT_CANDIDATES[kind]:
        if os.path.exists(path):
            return path
    return None

RANDOM_SEED = 20260731

# Fraza kontrolna pozwala potwierdzić, że OCR odczytał treść po restarcie.
CONTROL_PHRASE = "SYGNATURA RESTARTU OCR DELTA ECHO 2026"

BODY = [
    "Dokument laboratoryjny do próby przerwania przetwarzania.",
    "Treść jest syntetyczna i nie zawiera danych osobowych.",
    "Sprawdzana jest odporność potoku OCR na restart usługi.",
    "Zażółć gęślą jaźń — kontrola polskich znaków diakrytycznych.",
    "Wiersz kontrolny numer jeden z tekstem uzupełniającym stronę.",
    "Wiersz kontrolny numer dwa z tekstem uzupełniającym stronę.",
    "Wiersz kontrolny numer trzy z tekstem uzupełniającym stronę.",
    "Wiersz kontrolny numer cztery z tekstem uzupełniającym stronę.",
    "Wiersz kontrolny numer pięć z tekstem uzupełniającym stronę.",
    "Wiersz kontrolny numer sześć z tekstem uzupełniającym stronę.",
    "Wiersz kontrolny numer siedem z tekstem uzupełniającym stronę.",
    "Wiersz kontrolny numer osiem z tekstem uzupełniającym stronę.",
]


def build_page(index, pages, width, height):
    img = Image.new("L", (width, height), 252)
    draw = ImageDraw.Draw(img)
    f_head = ImageFont.truetype(pick_font("serif_bold"), 62)
    f_ctl = ImageFont.truetype(pick_font("sans"), 50)
    f_body = ImageFont.truetype(pick_font("serif"), 42)

    y = 170
    draw.text((150, y), "HomeOS M3 — próba E1-13", font=f_head, fill=15)
    y += 110
    draw.line((150, y, width - 150, y), fill=90, width=3)
    y += 60
    draw.text((150, y), CONTROL_PHRASE, font=f_ctl, fill=15)
    y += 100
    for line in BODY:
        draw.text((150, y), line, font=f_body, fill=30)
        y += 62
    draw.text((150, height - 170), f"strona {index} z {pages}", font=f_body, fill=60)

    # Lekkie artefakty imitujące skan: rozmycie, przekrzywienie i szum.
    img = img.filter(ImageFilter.GaussianBlur(0.55))
    img = img.rotate(random.uniform(-0.45, 0.45), resample=Image.BICUBIC, fillcolor=252)
    noise = ImageDraw.Draw(img)
    for _ in range(6000):
        noise.point(
            (random.randrange(width), random.randrange(height)),
            fill=random.randrange(160, 235),
        )
    return img


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("out_path", help="plik wynikowy PDF")
    parser.add_argument("--pages", type=int, default=20, help="liczba stron (domyślnie 20)")
    parser.add_argument("--dpi", type=int, default=200, help="rozdzielczość (domyślnie 200)")
    parser.add_argument(
        "--overwrite", action="store_true", help="zezwól na zastąpienie istniejącego pliku"
    )
    args = parser.parse_args()

    if args.pages < 1:
        print("BŁĄD: --pages musi być dodatnie", file=sys.stderr)
        return 2
    if os.path.exists(args.out_path) and not args.overwrite:
        print(
            f"BŁĄD: plik {args.out_path} już istnieje. Użyj --overwrite świadomie.",
            file=sys.stderr,
        )
        return 5
    missing = [kind for kind in FONT_CANDIDATES if pick_font(kind) is None]
    if missing:
        print(
            f"BŁĄD: brak czcionek dla: {', '.join(missing)}; "
            "uruchom generator w kontenerze Paperless",
            file=sys.stderr,
        )
        return 3
    for kind in FONT_CANDIDATES:
        print(f"czcionka_{kind}={pick_font(kind)}", file=sys.stderr)

    width = int(8.27 * args.dpi)
    height = int(11.69 * args.dpi)
    random.seed(RANDOM_SEED)

    tmp_dir = os.path.dirname(os.path.abspath(args.out_path))
    os.makedirs(tmp_dir, mode=0o700, exist_ok=True)
    jpegs = []
    for index in range(1, args.pages + 1):
        img = build_page(index, args.pages, width, height)
        path = os.path.join(tmp_dir, f".e1-13-page-{index}.jpg")
        img.save(path, "JPEG", quality=78, dpi=(args.dpi, args.dpi))
        jpegs.append(path)

    import img2pdf

    with open(args.out_path, "wb") as fh:
        fh.write(img2pdf.convert(jpegs))
    for path in jpegs:
        os.unlink(path)
    os.chmod(args.out_path, 0o600)

    with open(args.out_path, "rb") as fh:
        data = fh.read()
    print(f"plik={args.out_path}")
    print(f"strony={args.pages}")
    print(f"rozmiar={len(data)}")
    print(f"sha256={hashlib.sha256(data).hexdigest()}")
    print(f"fraza_kontrolna={CONTROL_PHRASE}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
