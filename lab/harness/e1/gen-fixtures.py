"""Generator wyłącznie syntetycznych fixture E1.

Uruchamiany wewnątrz kontenera Paperless (ma Pillow, fpdf2, img2pdf, poppler).
Nie zawiera danych osobowych ani rzeczywistych numerów. Nie modyfikuje żadnego
istniejącego pliku poza katalogiem wyjściowym.

Użycie:
    python3 gen-fixtures.py [katalog_wyjściowy] [--only NAZWA[,NAZWA...]]

Katalog wyjściowy domyślnie pochodzi z M3_FIXTURE_DIR, a w ostatniej kolejności
z /tmp/m3-fixtures.

Powtarzalność, sprawdzona empirycznie:

- DOC-09A, DOC-09B, DOC-10 i DOC-DEL-01 są powtarzalne bajtowo — data utworzenia
  PDF jest ustawiona na stałą wartość;
- DOC-08 jest powtarzalny, bo powstaje z kopii DOC-09A;
- DOC-06 ma stałe ziarno losowe, stały układ i stały rozmiar, ale NIE jest
  powtarzalny bajtowo: img2pdf osadza datę utworzenia i losowy identyfikator
  dokumentu. Porównuj go po rozmiarze i liczbie stron, nie po sumie SHA-256.
"""

import argparse
import hashlib
import os
import random
import shutil
import subprocess
import sys
from datetime import datetime, timezone

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT_DIR = os.environ.get("M3_FONT_DIR", "/usr/share/fonts/truetype/liberation")
SERIF = os.path.join(FONT_DIR, "LiberationSerif-Regular.ttf")
SERIF_B = os.path.join(FONT_DIR, "LiberationSerif-Bold.ttf")
SANS = os.path.join(FONT_DIR, "LiberationSans-Regular.ttf")

RANDOM_SEED = 20260730

PAGES = [
    (
        "PROTOKOL LABORATORYJNY HOMEOS M3",
        "STRONA PIERWSZA",
        "KONTROLA ALFA PIERWSZA STRONA PROTOKOLU",
        [
            "Niniejszy protokol opisuje przebieg proby laboratoryjnej",
            "przeprowadzonej w izolowanym srodowisku badawczym M3.",
            "Zapis obejmuje kolejne etapy przetwarzania dokumentu",
            "wielostronicowego oraz pomiary zuzycia zasobow.",
            "",
            "Zakres proby obejmuje rozpoznawanie tekstu, budowe",
            "warstwy tekstowej oraz kontrole liczby stron.",
            "Material jest w calosci syntetyczny i nie zawiera",
            "zadnych danych osobowych ani rzeczywistych numerow.",
            "",
            "Punkt pierwszy: przyjecie pliku wejsciowego.",
            "Punkt drugi: uruchomienie procesu rozpoznawania.",
            "Punkt trzeci: zapis wynikow oraz sum kontrolnych.",
        ],
    ),
    (
        "PROTOKOL LABORATORYJNY HOMEOS M3",
        "STRONA DRUGA",
        "SEKCJA POSREDNIA NUMER DWA",
        [
            "Druga czesc protokolu opisuje warunki poczatkowe.",
            "Srodowisko pracuje w konfiguracji zrodlowej i korzysta",
            "z jednego wspoldzielonego brokera zadan.",
            "",
            "Wszystkie pomiary sa wykonywane w tej samej sesji,",
            "bez restartu uslug oraz bez zmiany konfiguracji.",
            "",
            "Tabela kontrolna:",
            "  pozycja pierwsza .................. wartosc 101",
            "  pozycja druga ..................... wartosc 202",
            "  pozycja trzecia ................... wartosc 303",
            "",
            "Suma pozycji kontrolnych wynosi 606 jednostek.",
        ],
    ),
    (
        "PROTOKOL LABORATORYJNY HOMEOS M3",
        "STRONA TRZECIA",
        "SEKCJA POSREDNIA NUMER TRZY",
        [
            "Trzecia czesc protokolu opisuje przebieg pomiarow.",
            "Probki zuzycia procesora i pamieci sa pobierane",
            "w rownych odstepach czasu przez caly czas trwania",
            "zadania rozpoznawania tekstu.",
            "",
            "Kazda strona wejsciowa jest przetwarzana osobno,",
            "a wynik laczony jest w jeden dokument wyjsciowy.",
            "",
            "Uwaga: material powstal przez rasteryzacje tekstu,",
            "a nie przez skanowanie papierowego oryginalu.",
            "Wynik tej proby jest wynikiem wstepnym.",
        ],
    ),
    (
        "PROTOKOL LABORATORYJNY HOMEOS M3",
        "STRONA CZWARTA",
        "KONTROLA OMEGA OSTATNIA STRONA PROTOKOLU",
        [
            "Czwarta i ostatnia czesc protokolu zamyka zapis proby.",
            "Po zakonczeniu przetwarzania nalezy porownac liczbe",
            "stron dokumentu wyjsciowego z liczba stron wejscia.",
            "",
            "Nastepnie sprawdzana jest obecnosc frazy kontrolnej",
            "na pierwszej oraz na ostatniej stronie dokumentu.",
            "",
            "Zakonczenie protokolu laboratoryjnego HomeOS M3.",
            "Dokument nie zawiera danych osobowych.",
        ],
    ),
]

TEXT_DOCS = {
    "DOC-09A.pdf": (
        "HomeOS M3 DOC-09A dokument bazowy rodziny duplikatow",
        [
            "Dokument bazowy rodziny duplikatow laboratorium M3.",
            "",
            "SYGNATURA DUPLIKATU ALFA BRAVO 2026",
            "",
            "Material jest w calosci syntetyczny i nie zawiera danych osobowych.",
            # Treść jest częścią sumy kontrolnej fixture zapisanej w manifeście,
            # więc nie zmieniaj tych linii bez aktualizacji manifestu.
            "Sluzy wylacznie do sprawdzenia zachowania Paperless 3.0.4 przy",
            "ponownym przeslaniu tego samego pliku wejsciowego.",
            "",
            "Pozycja kontrolna: 4242 jednostki.",
        ],
    ),
    "DOC-10-zażółć-gęślą-jaźń.pdf": (
        "HomeOS M3 DOC-10 — zażółć gęślą jaźń",
        [
            "Dokument kontrolny kodowania znaków narodowych.",
            "",
            "PROTOKÓŁ KODOWANIA HOMEOS DZIESIĘĆ",
            "",
            "Kontrola kodowania: zażółć gęślą jaźń.",
            "Wielkie litery: Ą Ć Ę Ł Ń Ó Ś Ź Ż",
            "Małe litery: ą ć ę ł ń ó ś ź ż",
            "",
            "Zdanie kontrolne z pełnym zestawem znaków:",
            "Pchnąć w tę łódź jeża lub ośm skrzyń fig.",
            "",
            "Materiał jest syntetyczny i nie zawiera danych osobowych.",
        ],
    ),
    "DOC-DEL-01.pdf": (
        "HomeOS M3 DOC-DEL-01 dokument jednorazowy",
        [
            "Dokument jednorazowy utworzony wyłącznie do testu operacji delete.",
            "",
            "SYGNATURA JEDNORAZOWA DELETE 2026",
            "",
            "Po zakończeniu próby rekord zostaje usunięty przez API.",
            "Materiał jest syntetyczny i nie zawiera danych osobowych.",
        ],
    ),
}


def build_raster_pdf(out_dir):
    """Czterostronicowy PDF rastrowy bez warstwy tekstowej, imitujący skan 200 dpi."""
    width, height = 1654, 2339
    random.seed(RANDOM_SEED)
    jpegs = []
    for idx, (head, sub, control, body) in enumerate(PAGES, start=1):
        img = Image.new("L", (width, height), 252)
        draw = ImageDraw.Draw(img)
        f_head = ImageFont.truetype(SERIF_B, 62)
        f_sub = ImageFont.truetype(SERIF_B, 46)
        f_ctl = ImageFont.truetype(SANS, 50)
        f_body = ImageFont.truetype(SERIF, 42)

        y = 170
        draw.text((150, y), head, font=f_head, fill=15)
        y += 105
        draw.text((150, y), sub, font=f_sub, fill=25)
        y += 90
        draw.line((150, y, width - 150, y), fill=90, width=3)
        y += 60
        draw.text((150, y), control, font=f_ctl, fill=15)
        y += 100
        for line in body:
            draw.text((150, y), line, font=f_body, fill=30)
            y += 62
        draw.text((150, height - 170), f"strona {idx} z {len(PAGES)}", font=f_body, fill=60)

        # Lekkie artefakty skanu: rozmycie, przekrzywienie i szum.
        img = img.filter(ImageFilter.GaussianBlur(0.55))
        img = img.rotate(random.uniform(-0.45, 0.45), resample=Image.BICUBIC, fillcolor=252)
        noise = ImageDraw.Draw(img)
        for _ in range(6000):
            noise.point((random.randrange(width), random.randrange(height)),
                        fill=random.randrange(160, 235))

        path = os.path.join(out_dir, f"page-{idx}.jpg")
        img.save(path, "JPEG", quality=78, dpi=(200, 200))
        jpegs.append(path)

    import img2pdf

    # img2pdf stempluje datę utworzenia i losowy identyfikator dokumentu, więc
    # wynik ma stały rozmiar i stałą treść, ale nie jest powtarzalny bajtowo.
    # `nodate=True` usuwa datę, lecz zmienia rozmiar zapisany w manifeście
    # i nadal nie usuwa identyfikatora, dlatego nie jest tu używane.
    with open(os.path.join(out_dir, "DOC-06.pdf"), "wb") as fh:
        fh.write(img2pdf.convert(jpegs))
    for path in jpegs:
        os.unlink(path)


def build_text_pdf(path, title, lines):
    from fpdf import FPDF, XPos, YPos

    pdf = FPDF(format="A4")
    # Stała data utworzenia, aby regeneracja fixture była powtarzalna bajtowo.
    pdf.set_creation_date(datetime(2026, 7, 30, 12, 0, 0, tzinfo=timezone.utc))
    pdf.add_font("lib", "", SERIF)
    pdf.add_font("lib", "B", SERIF_B)
    pdf.add_page()
    pdf.set_font("lib", "B", 16)
    pdf.multi_cell(0, 10, text=title, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.ln(4)
    pdf.set_font("lib", "", 12)
    for line in lines:
        pdf.multi_cell(0, 7, text=line, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.output(path)


def build_duplicate(out_dir):
    """DOC-09B: kopia bajtowo identyczna z DOC-09A."""
    src = os.path.join(out_dir, "DOC-09A.pdf")
    if not os.path.exists(src):
        raise SystemExit("DOC-09A.pdf musi powstać przed DOC-09B.pdf")
    shutil.copyfile(src, os.path.join(out_dir, "DOC-09B.pdf"))


def build_corrupted(out_dir):
    """DOC-08: uszkodzony PDF z kopii DOC-09A — nagłówek zostaje, xref zniszczony."""
    src = os.path.join(out_dir, "DOC-09A.pdf")
    if not os.path.exists(src):
        raise SystemExit("DOC-09A.pdf musi powstać przed DOC-08.pdf")
    with open(src, "rb") as fh:
        raw = fh.read()
    cut = int(len(raw) * 0.55)
    broken = bytearray(raw[:cut])
    broken += b"\n0000000000 65535 f \n%%EOF\n"
    for pos in range(200, min(400, cut)):
        broken[pos] = (broken[pos] + 137) % 256
    with open(os.path.join(out_dir, "DOC-08.pdf"), "wb") as fh:
        fh.write(bytes(broken))


def report(out_dir):
    print("=== WYGENEROWANE ===")
    for name in sorted(os.listdir(out_dir)):
        path = os.path.join(out_dir, name)
        with open(path, "rb") as fh:
            data = fh.read()
        print(f"{name}\tsize={len(data)}\tsha256={hashlib.sha256(data).hexdigest()}")

    print("=== WŁAŚCIWOŚCI PDF ===")
    for name in sorted(os.listdir(out_dir)):
        path = os.path.join(out_dir, name)
        info = subprocess.run(["pdfinfo", path], capture_output=True, text=True)
        pages = ""
        for line in info.stdout.splitlines():
            if line.startswith("Pages:"):
                pages = line.split()[1]
        txt = subprocess.run(["pdftotext", path, "-"], capture_output=True, text=True)
        chars = len("".join(txt.stdout.split()))
        print(f"{name}\tpages={pages or 'n/a'}\ttext_chars={chars}\tpdfinfo_rc={info.returncode}")


def main():
    parser = argparse.ArgumentParser(
        description="Generuje wyłącznie syntetyczne fixture E1.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Wszystkie materiały są syntetyczne. Nie kopiuj wyników do Git.",
    )
    parser.add_argument(
        "out_dir",
        nargs="?",
        default=os.environ.get("M3_FIXTURE_DIR", "/tmp/m3-fixtures"),
        help="katalog wyjściowy (domyślnie M3_FIXTURE_DIR lub /tmp/m3-fixtures)",
    )
    parser.add_argument(
        "--only",
        default="",
        help="lista rozdzielona przecinkami: raster,text,duplicate,corrupted",
    )
    parser.add_argument(
        "--keep",
        action="store_true",
        help="nie czyść katalogu wyjściowego przed generowaniem",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="zezwól na zastąpienie istniejących plików w katalogu wyjściowym",
    )
    args = parser.parse_args()

    for font in (SERIF, SERIF_B, SANS):
        if not os.path.exists(font):
            print(f"BŁĄD: brak czcionki {font}; uruchom generator w kontenerze Paperless",
                  file=sys.stderr)
            return 3

    wanted = {s.strip() for s in args.only.split(",") if s.strip()} or \
        {"raster", "text", "duplicate", "corrupted"}
    unknown = wanted - {"raster", "text", "duplicate", "corrupted"}
    if unknown:
        print(f"BŁĄD: nieznane grupy: {', '.join(sorted(unknown))}", file=sys.stderr)
        return 2

    # Bez --overwrite generator nie dotyka katalogu, w którym już coś leży:
    # istniejące fixture są materiałem wejściowym prób i nie wolno ich stracić.
    existing = os.path.isdir(args.out_dir) and os.listdir(args.out_dir)
    if existing and not args.overwrite:
        print(
            f"BŁĄD: katalog {args.out_dir} zawiera {len(existing)} plików. "
            "Użyj --overwrite świadomie albo wskaż pusty katalog.",
            file=sys.stderr,
        )
        return 5

    if not args.keep and args.overwrite:
        shutil.rmtree(args.out_dir, ignore_errors=True)
    os.makedirs(args.out_dir, mode=0o700, exist_ok=True)

    if "raster" in wanted:
        build_raster_pdf(args.out_dir)
    text_names = set(TEXT_DOCS) if "text" in wanted else set()
    if "duplicate" in wanted or "corrupted" in wanted:
        text_names.add("DOC-09A.pdf")
    for name in sorted(text_names):
        title, lines = TEXT_DOCS[name]
        build_text_pdf(os.path.join(args.out_dir, name), title, lines)
    if "duplicate" in wanted:
        build_duplicate(args.out_dir)
    if "corrupted" in wanted:
        build_corrupted(args.out_dir)

    for name in os.listdir(args.out_dir):
        os.chmod(os.path.join(args.out_dir, name), 0o600)

    report(args.out_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
