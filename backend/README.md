<p align="center"><a href="https://laravel.com" target="_blank"><img src="https://raw.githubusercontent.com/laravel/art/master/logo-lockup/5%20SVG/2%20CMYK/1%20Full%20Color/laravel-logolockup-cmyk-red.svg" width="400" alt="Laravel Logo"></a></p>

<p align="center">
<a href="https://github.com/laravel/framework/actions"><img src="https://github.com/laravel/framework/workflows/tests/badge.svg" alt="Build Status"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/dt/laravel/framework" alt="Total Downloads"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/v/laravel/framework" alt="Latest Stable Version"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/l/laravel/framework" alt="License"></a>
</p>

## About Laravel

Laravel is a web application framework with expressive, elegant syntax. We believe development must be an enjoyable and creative experience to be truly fulfilling. Laravel takes the pain out of development by easing common tasks used in many web projects, such as:

- [Simple, fast routing engine](https://laravel.com/docs/routing).
- [Powerful dependency injection container](https://laravel.com/docs/container).
- Multiple back-ends for [session](https://laravel.com/docs/session) and [cache](https://laravel.com/docs/cache) storage.
- Expressive, intuitive [database ORM](https://laravel.com/docs/eloquent).
- Database agnostic [schema migrations](https://laravel.com/docs/migrations).
- [Robust background job processing](https://laravel.com/docs/queues).
- [Real-time event broadcasting](https://laravel.com/docs/broadcasting).

Laravel is accessible, powerful, and provides tools required for large, robust applications.

## Learning Laravel

Laravel has the most extensive and thorough [documentation](https://laravel.com/docs) and video tutorial library of all modern web application frameworks, making it a breeze to get started with the framework.

You may also try the [Laravel Bootcamp](https://bootcamp.laravel.com), where you will be guided through building a modern Laravel application from scratch.

If you don't feel like reading, [Laracasts](https://laracasts.com) can help. Laracasts contains thousands of video tutorials on a range of topics including Laravel, modern PHP, unit testing, and JavaScript. Boost your skills by digging into our comprehensive video library.

## Laravel Sponsors

We would like to extend our thanks to the following sponsors for funding Laravel development. If you are interested in becoming a sponsor, please visit the [Laravel Partners program](https://partners.laravel.com).

### Premium Partners

- **[Vehikl](https://vehikl.com)**
- **[Tighten Co.](https://tighten.co)**
- **[Kirschbaum Development Group](https://kirschbaumdevelopment.com)**
- **[64 Robots](https://64robots.com)**
- **[Curotec](https://www.curotec.com/services/technologies/laravel)**
- **[DevSquad](https://devsquad.com/hire-laravel-developers)**
- **[Redberry](https://redberry.international/laravel-development)**
- **[Active Logic](https://activelogic.com)**

## Contributing

Thank you for considering contributing to the Laravel framework! The contribution guide can be found in the [Laravel documentation](https://laravel.com/docs/contributions).

## Code of Conduct

In order to ensure that the Laravel community is welcoming to all, please review and abide by the [Code of Conduct](https://laravel.com/docs/contributions#code-of-conduct).

## Security Vulnerabilities

If you discover a security vulnerability within Laravel, please send an e-mail to Taylor Otwell via [taylor@laravel.com](mailto:taylor@laravel.com). All security vulnerabilities will be promptly addressed.

## Essay Document Generator

This project includes an Artisan command to generate academic essay documents in `.docx` format with standard formatting.

### Usage

```bash
php artisan essay:generate [options]
```

### Options

- `--title` : Essay title (default: varies by language)
- `--student` : Student name (default: varies by language)
- `--student-id` : Student ID (default: 12345678)
- `--class` : Class name (default: varies by language)
- `--course` : Course name (default: varies by language)
- `--instructor` : Instructor name (default: varies by language)
- `--university` : University name (default: varies by language)
- `--department` : Department name (default: varies by language)
- `--language=vi|en` : Language (default: vi)
- `--citation=apa|ieee` : Citation style (default: apa)
- `--out` : Output path (default: storage/app/essays/<slugified-title>.docx)
- `--from-markdown` : Parse content from Markdown file

### Examples

Generate an essay with custom information:

```bash
php artisan essay:generate \
  --title="Digital Bookstore System" \
  --student="John Doe" \
  --student-id="12345678" \
  --class="CS2024" \
  --course="Graduation Thesis" \
  --instructor="Dr. Jane Smith" \
  --university="ABC University" \
  --department="Department of Computer Science" \
  --language=en
```

Generate from a Markdown file:

```bash
php artisan essay:generate \
  --title="My Essay" \
  --student="Jane Smith" \
  --student-id="87654321" \
  --from-markdown=docs/essay.md \
  --language=en
```

Generate with Vietnamese language (default):

```bash
php artisan essay:generate \
  --title="Hệ thống Thư viện Điện tử" \
  --student="Nguyễn Văn A" \
  --student-id="12345678"
```

### Document Structure

The generated document includes:

1. **Cover Page**: University, department, course, title, student info, instructor, date (no page number)
2. **Acknowledgements**: Optional acknowledgement section
3. **Abstract**: 150-250 word summary with keywords
4. **Table of Contents**: Placeholder for auto-generated TOC
5. **Introduction**: Background, problem statement, objectives, scope, methodology
6. **Literature Review**: Related research and theoretical foundations
7. **Requirements & System Design**: Functional and non-functional requirements
8. **Architecture & Technology**: Backend (Laravel 12, Sanctum, REST) and Frontend (Flutter 3, Material 3)
9. **Data Model**: Database schema with tables for users, authors, categories, books, orders, wallets, reviews, votes
10. **Implementation & Features**: User management, catalog, orders, wallet, reviews
11. **Testing & Evaluation**: Unit and integration testing
12. **Discussion**: Limitations and future work
13. **Conclusion**: Summary of achievements
14. **References**: Bibliography in APA/IEEE format
15. **Appendices**: Figures, tables, and supplementary materials

### Formatting

- **Paper**: A4
- **Margins**: 2.54cm (1 inch) on all sides
- **Font**: Times New Roman, 12pt
- **Line Spacing**: 1.5
- **Alignment**: Justified
- **Paragraph Spacing**: 6pt before/after
- **Headings**: Numbered (1, 1.1, 1.1.1)
- **Page Numbers**: Starting from first content section (footer, centered)

## PDF Text Extraction with OCR

This project includes a PDF text extraction feature with OCR (Optical Character Recognition) support for extracting text from both regular and scanned PDF documents.

### System Dependencies

Before using the OCR features, you need to install the following system dependencies:

#### Tesseract OCR

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install tesseract-ocr tesseract-ocr-eng tesseract-ocr-vie
```

**macOS:**
```bash
brew install tesseract tesseract-lang
```

**Windows:**
```bash
choco install tesseract
```

Or download the installer from: https://github.com/UB-Mannheim/tesseract/wiki

#### ImageMagick & Imagick Extension

**Ubuntu/Debian:**
```bash
sudo apt-get install php-imagick imagemagick ghostscript
```

**macOS:**
```bash
brew install imagemagick ghostscript
pecl install imagick
```

**Windows:**
1. Download ImageMagick from: https://imagemagick.org/script/download.php
2. Install the PHP imagick extension via PECL or download pre-compiled DLL

### PHP Packages

The required Composer packages are already included in `composer.json`:

```bash
composer require thiagoalessio/tesseract_ocr spatie/pdf-to-image
```

### Configuration

Add the following environment variables to your `.env` file:

```env
TESSERACT_PATH=/usr/bin/tesseract
OCR_TIMEOUT=120
```

The configuration is stored in `config/services.php`:

```php
'tesseract' => [
    'binary' => env('TESSERACT_PATH', '/usr/bin/tesseract'),
    'languages' => ['eng', 'vie'],
    'timeout' => env('OCR_TIMEOUT', 120),
],
```

### API Endpoint

**Endpoint:** `POST /api/books/{book}/extract-text`

**Authentication:** Required (Sanctum token)

**Rate Limiting:** 10 requests per minute

**Request Parameters:**

| Parameter | Type | Required | Default | Options | Description |
|-----------|------|----------|---------|---------|-------------|
| `pages` | string | No | All pages | e.g., "1,5,10,30-40" | Page selection (comma-separated, ranges allowed) |
| `method` | string | No | `text` | `text`, `ocr`, `combined` | Extraction method |
| `language` | string | No | `eng` | `eng`, `vie`, `eng+vie` | OCR language |

### Extraction Methods

#### 1. `text` - Embedded Text Only (Fast, ~1-5 seconds)

Extracts embedded text from PDFs using the PDF parser. This is the fastest method but only works with PDFs that contain selectable text.

```bash
curl -X POST https://api.example.com/api/books/123/extract-text \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "pages": "1,5,10",
    "method": "text"
  }'
```

**Use Case:** Regular PDFs with embedded text (e.g., generated from Word, LaTeX)

#### 2. `ocr` - OCR Only (Slow, ~2-10 seconds per page)

Converts each PDF page to an image and performs OCR to extract text. This is the slowest method but works with scanned PDFs.

```bash
curl -X POST https://api.example.com/api/books/123/extract-text \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "pages": "1-5",
    "method": "ocr",
    "language": "eng+vie"
  }'
```

**Use Case:** Scanned documents, image-based PDFs

#### 3. `combined` - Hybrid Approach (Recommended, Adaptive)

Intelligently combines both methods:
1. First tries to extract embedded text from each page
2. If a page has less than 10 characters, uses OCR as fallback
3. Returns combined results

```bash
curl -X POST https://api.example.com/api/books/123/extract-text \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "pages": "1,5,10,30-40",
    "method": "combined",
    "language": "vie"
  }'
```

**Use Case:** Mixed PDFs (some pages with text, some scanned), unknown PDF types

### Response Format

**Success Response (200 OK):**

```json
{
  "success": true,
  "text": "Extracted text content...",
  "total_pages": 250,
  "extracted_pages": [1, 5, 10, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40],
  "page_count": 14,
  "method_used": "combined",
  "extraction_details": {
    "embedded_text_pages": 12,
    "ocr_pages": 2,
    "failed_pages": 0
  },
  "processing_time_seconds": 12.5
}
```

**Error Responses:**

```json
// 400 Bad Request - Invalid parameters
{
  "success": false,
  "message": "Invalid page format. Use only numbers, commas, and hyphens."
}

// 403 Forbidden - No permission
{
  "success": false,
  "message": "You don't have permission to access this book"
}

// 404 Not Found - No PDF
{
  "success": false,
  "message": "Book has no PDF file"
}

// 500 Internal Server Error - OCR not available
{
  "success": false,
  "message": "OCR engine not available. Please install Tesseract OCR."
}

// 500 Internal Server Error - Imagick not available
{
  "success": false,
  "message": "Image processing not available. Please install Imagick extension."
}
```

### Language Support

The system supports three language options:

- **`eng`** - English only
- **`vie`** - Vietnamese only
- **`eng+vie`** - Both English and Vietnamese (multilingual)

You can add more languages by:
1. Installing the Tesseract language data: `sudo apt-get install tesseract-ocr-<lang>`
2. Adding the language code to `config/services.php`:

```php
'tesseract' => [
    'binary' => env('TESSERACT_PATH', '/usr/bin/tesseract'),
    'languages' => ['eng', 'vie', 'fra', 'deu'], // Add more languages here
    'timeout' => env('OCR_TIMEOUT', 120),
],
```

### Performance Considerations

| Method | Speed | Accuracy | Best For |
|--------|-------|----------|----------|
| `text` | Very Fast (1-5s) | High (100%) | Regular PDFs with embedded text |
| `ocr` | Slow (2-10s/page) | Good (80-95%) | Scanned documents |
| `combined` | Adaptive | High | Unknown PDF types, mixed content |

**Tips:**
- Use `text` method for regular PDFs to get instant results
- Use `combined` method when unsure about PDF type
- OCR processing is CPU/memory intensive (300-500MB per page)
- For large documents (>20 pages), consider using queue jobs
- Higher DPI (300) provides better OCR accuracy but slower processing
- Temporary image files are automatically cleaned up after OCR

### Examples

**Extract all pages with OCR:**
```bash
POST /api/books/123/extract-text
{
  "method": "ocr",
  "language": "eng"
}
```

**Extract specific pages with combined method:**
```bash
POST /api/books/123/extract-text
{
  "pages": "1,5,10-15",
  "method": "combined",
  "language": "eng+vie"
}
```

**Extract Vietnamese text only:**
```bash
POST /api/books/123/extract-text
{
  "pages": "1-20",
  "method": "ocr",
  "language": "vie"
}
```

### Testing

The test suite includes comprehensive tests for all extraction methods:

```bash
php artisan test --filter PdfTextExtractionTest
```

**Test Coverage:**
- ✅ Text extraction method
- ✅ OCR extraction method
- ✅ Combined extraction method
- ✅ Language parameter validation
- ✅ Method parameter validation
- ✅ Processing time tracking
- ✅ Extraction details metadata
- ✅ All existing tests for page selection and validation

### Troubleshooting

**Issue: "OCR engine not available"**
- Ensure Tesseract is installed: `tesseract --version`
- Check TESSERACT_PATH in `.env` points to correct binary
- Verify Tesseract is executable: `which tesseract`

**Issue: "Image processing not available"**
- Ensure Imagick extension is installed: `php -m | grep imagick`
- Install ImageMagick: `sudo apt-get install imagemagick`
- Install Ghostscript: `sudo apt-get install ghostscript`

**Issue: "OCR processing failed"**
- Check Tesseract language data is installed
- Verify PDF is not corrupted
- Ensure sufficient memory (OCR needs 300-500MB per page)
- Check timeout settings in `.env`

**Issue: Low OCR accuracy**
- Increase image resolution (default is 300 DPI)
- Ensure PDF scan quality is good
- Use correct language parameter
- Try different language combinations (e.g., `eng+vie`)

**Issue: Slow performance**
- Use `text` method for regular PDFs
- Reduce number of pages extracted at once
- Consider implementing queue jobs for large extractions
- Increase timeout in `.env` if needed

## Complete Essay Generator

This project includes a specialized command to generate a complete academic essay about the My Digital Bookstore project in Vietnamese:

### Usage

```bash
php artisan essay:generate-full [options]
```

### Options

- `--student` : Student name (default: "Nguyễn Văn A")
- `--student-id` : Student ID (default: "20210001")
- `--class` : Class name (default: "CNTT-K64")
- `--course` : Course name (default: "Đồ án môn học")
- `--instructor` : Instructor name (default: "TS. Nguyễn Văn B")
- `--university` : University name (default: "TRƯỜNG ĐẠI HỌC CÔNG NGHỆ")
- `--department` : Department name (default: "KHOA CÔNG NGHỆ THÔNG TIN")
- `--output` : Output path (default: "storage/app/essays/my_digital_bookstore_essay.docx")

### Example

```bash
php artisan essay:generate-full \
  --student="Trần Văn B" \
  --student-id="20210123" \
  --class="CNTT-K65" \
  --university="TRƯỜNG ĐẠI HỌC KINH TẾ QUỐC DÂN" \
  --department="KHOA HỆ THỐNG THÔNG TIN" \
  --course="Lập trình web nâng cao" \
  --instructor="PGS.TS. Nguyễn Thị C"
```

### Document Structure

The generated document includes complete content (20-30 pages) in formal academic Vietnamese:

1. **Trang bìa (Cover Page)**: University, department, course title, student info, instructor, date
2. **Lời cảm ơn (Acknowledgements)**: Formal thanks to instructors, family, and friends
3. **Tóm tắt (Abstract)**: 200-250 word overview with keywords
4. **Mục lục (Table of Contents)**: Auto-generated TOC
5. **Chương 1 - Mở đầu (Introduction)**: Background, objectives, scope, methodology, document structure
6. **Chương 2 - Cơ sở lý thuyết và công nghệ (Theory & Technology)**: E-commerce, REST API, Laravel, Flutter, state management, similar systems
7. **Chương 3 - Phân tích và thiết kế hệ thống (Analysis & Design)**: Requirements, use cases, architecture, database design, API design
8. **Chương 4 - Triển khai hệ thống (Implementation)**: Backend (Laravel 12, models, migrations, Sanctum, controllers, PDF management) and Frontend (Flutter 3, services, screens, navigation, storage, PDF reader, i18n, themes)
9. **Chương 5 - Kiểm thử và đánh giá (Testing & Evaluation)**: Backend tests, frontend tests, integration tests, performance evaluation
10. **Chương 6 - Kết luận và hướng phát triển (Conclusion & Future Work)**: Achievements, limitations, future improvements
11. **Tài liệu tham khảo (References)**: APA 7 format bibliography
12. **Phụ lục (Appendices)**: ERD diagram, API endpoints table, UI screenshots placeholders, project structure

All content is written in formal academic Vietnamese style with proper citations and technical details reflecting the actual My Digital Bookstore codebase.
### Troubleshooting

If you encounter the error `Class "PhpOffice\PhpWord\PhpWord" not found`, it means the dependencies are not properly installed. Follow these steps:

1. **Install Composer Dependencies**:
   ```bash
   composer install
   ```

2. **If the error persists, regenerate the autoloader**:
   ```bash
   composer dump-autoload
   ```

3. **Verify the installation**:
   ```bash
   composer show phpoffice/phpword
   ```
   
   This should display the package version (^1.3) if installed correctly.

4. **On Windows**: Make sure you run these commands in the same directory where `composer.json` is located (the `backend` directory).

## License

The Laravel framework is open-sourced software licensed under the [MIT license](https://opensource.org/licenses/MIT).
