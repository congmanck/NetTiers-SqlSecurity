# NetTiers SQL memory protection

## Chọn template trong CodeSmith

Bộ đang chỉnh: `D:\CursorAICty\NetTiers-SqlSecurity`. Trong CodeSmith mở `NetTiers.cst` tại thư mục này và compile/reload template để bỏ cache template cũ. Nếu dùng NetTiers.csp, chọn lại template mới trong UI và lưu một profile riêng; profile gốc trong source còn trỏ thư mục PC2, chưa được sửa. Không dùng profile trỏ bộ template cũ.

Chọn SQL Server, EnterpriseLibrary `v3_1`, VisualStudioVersion `v2013` và output thử riêng, ví dụ `D:\CursorAI\HocPhiChung2025\.security-work\nettiers-codesmith-trial`. `ExecuteSql=False`; không chạy script SQL hoặc generate trực tiếp vào source đang dùng. Không đặt password thực trong profile bàn giao.

Bộ SQL bảo mật hiện chỉ hỗ trợ EnterpriseLibrary 3.1 đã kiểm thử. NetTiers.cst từ chối SQL provider với phiên bản khác trước luồng sinh file. CompilerVersion=v3.5 của generator không bị thay; code output cần Roslyn/C# 6 trở lên và SDK .NET Framework 4.8 hoặc cao hơn. Target framework của Data/SqlClient/entities output được nâng tối thiểu 4.8, giữ phiên bản cao hơn nếu đã chọn. Cần build bằng MSBuild/SDK mới phù hợp, không dùng compiler C# 3.5 để compile output.

## Những phần đã tích hợp

- Table provider base, view provider base và SqlNetTiersProvider sinh SecureSqlDatabase; constructor/config/setter chuyển input thành tham chiếu phiên. Getter chuỗi công khai dùng GetSafeConnectionString, không trả Password/User ID; đường execute nội bộ dùng tham chiếu phiên. ExportLegacy/CopyPassword đã bỏ; ExportStorageBytes và các lớp giải mã/DPAPI là internal.
- TransactionManager giữ lease đến sau connection/transaction, rollback khi stop trước commit và dispose đúng thứ tự. Nhánh ngoài SQL giữ template cũ.
- DataRepository thay provider trùng tên và bảo vệ tham chiếu trong ConnectionProvider. Utility giữ nguyên câu SQL/tên DB log hiện có, thêm lease/disposal/redaction và không ghi nguyên SQL text tự do. Không sửa template stored procedure/schema.
- Luồng generate tự ghi lại 9 file trong Security, thêm node project và Compile Include/System.Security. Namespace lấy từ DALNameSpace; không hardcode Accounts.Data. Source assets nằm trong SecuritySource/*.cs.txt, dùng marker __DAL_NAMESPACE__.
- AppConnection, form, Program và ReleaseProtection tiếp tục tích hợp bằng gói HocPhi-SqlSecurity-Porting riêng; generator này không tự sửa các file desktop đó.

Không chuyển token sql-session sang SqlConnection/SqlConnectionStringBuilder trực tiếp. Các caller/helper bên ngoài provider vẫn phải được chuyển sang API lease như hướng dẫn porting. Nếu file cấu hình có raw SQL connection string, ConfigurationManager/caller cũ vẫn có thể giữ bản sao plaintext; template provider không thay thế việc bảo vệ cấu hình trong AppConnection.

## Kiểm tra bằng CodeSmith trên máy có engine

1. Compile template mới, chọn ít nhất một table, một view và custom stored procedure đang dùng; generate với ExecuteSql=False vào output thử.
2. Kiểm tra 9 file Security, namespace, Compile Include, target framework và references; build output bằng compiler mới.
3. Generate lần hai cùng profile vào output thử. Chạy lại build và kiểm tra không mất Security hoặc thay adapter về SqlDatabase.
4. Copy script Convert-NetTiers.py vào scripts/security của solution thử và chạy --check. Mẫu namespace khác vẫn cần kiểm tra trực tiếp constructor/config/getter/raw connection; --check không phải chứng minh an toàn toàn bộ.
5. Chạy fixture và kiểm thử SQL/Windows auth, reader/dataset, transaction commit/rollback, provider reload, custom procedure, log nhạy cảm và tác vụ đồng thời trên DB thử. Không cấp credential thực qua command line.

## Backup và cài gói ở máy khác

Backup nguyên bộ trước sửa nằm ngoài thư mục template: `.security-work/NetTiers-before-security.zip`. Patch chỉ phần sửa: `.security-work/NetTiers-security.patch`.

Gói ZIP bàn giao là overlay: 8 template đã sửa, 5 assets mới và tài liệu. Giải nén đè vào **bản sao nguyên bộ NetTiers cùng phiên bản**; giữ các template còn lại, TemplateLib, UserLib và References từ bản gốc. Không có DLL dependency, CodeSmith engine, profile kết nối, khóa riêng hoặc dump trong ZIP. Không áp dụng overlay sang version NetTiers khác mà chưa đối chiếu patch. Không cập nhật trực tiếp bộ template cài chung của CodeSmith.

## Kết quả hiện tại và giới hạn

Đã audit tĩnh các template SQL, kiểm tra source asset và dựng riêng source Security/Transaction với hai namespace Accounts.Data và PortingTrial.Data. Cả hai compile và đạt 20 assertion mỗi namespace; dựng source hai lần giống nhau. Các file gốc ngoài 8 template sửa giữ nguyên byte, nhánh TransactionManager ngoài SQL giữ nguyên output cũ.

Chưa tìm thấy CodeSmith engine trên máy hiện tại. **Chưa chạy generate schema table/view/custom procedure bằng CodeSmith, chưa build toàn solution do CodeSmith sinh, chưa xác nhận nhánh project bằng engine thật.** Dựng literal source để test không thay thế engine generation. Các bước đó còn phải thực hiện trước sử dụng production. SecureString/DPAPI/obfuscation không cam kết chống mọi dump.

## Mặc định framework đã chỉnh

Template mới mặc định DotNetVersion=v4_8, EntLibVersion=v3_1 và ExecuteSql=False. Profile cũ chọn v4 được nâng lên v4_8 trong luồng SQL; csproj đầu ra tối thiểu v4.8. Profile lưu sẵn có thể ghi đè giá trị mặc định, nên vẫn kiểm tra EntLibVersion và ExecuteSql sau khi mở. Không tự tắt ExecuteSql nếu người dùng bật rõ trong profile. Lỗi trùng custom method GetByBillId/GetByBillIdHoanPhi chưa được sửa bởi thay đổi framework này.

Da sua nhanh IncludeComponents (Accounts.Services): project Services sinh ra cung toi thieu v4.8 de tham chieu Data/Entities v4.8.

## API hardening 2026-10-17
SqlConfiguration điều phối token, phiên và lưu/migrate DPAPI bên trong DAL. AppConnection và frmConfig cần bản port mới cùng DLL. Không dùng InternalsVisibleTo. Dữ liệu text/binary cũ giữ tương thích, EXE/plugin dùng API đã bỏ phải rebuild. Tests/Test-ApiHardening.ps1 kiểm tra hai namespace; chưa chạy CodeSmith với database thử nghiệm. Xem báo cáo API-HARDENING-20261017.md trong HocPhiChung2026.

## Cipher HPCF2
Cipher cũ và HPCF2 được nhận trong cấu hình, token HPC1 và nội dung cipher của DPAPI. Không thay vỏ token/DPAPI và không tự đổi chuẩn đã lưu. HPCF2 cần đúng HocPhi.dpk (64 byte) cạnh ứng dụng kể cả sau khi token hết hạn. Sao lưu khóa; không tạo lại/ghi đè khóa đang sử dụng. Chưa hỗ trợ xoay nhiều khóa. Mất khóa cần khôi phục khóa hoặc cấp lại cấu hình. Phát hành bộ đọc HocPhi và updater trước khi cấp cipher mới; không hạ về bản đọc cũ. Updater không nhận HPC1 trực tiếp. Không ghi khóa, mật khẩu hoặc cấu hình rõ vào log/Git.

Kiểm thử HPCF2: `Tests/Test-ApiHardening.ps1` kiểm tra đăng ký ConnectionCipher trong generator/project, đồng bộ 4 asset với nguồn HocPhi, rồi materialize và compile với Accounts.Data và PortingTrial.Data. Cả hai đạt 60 check API/session gồm test vector cố định và nhập/lưu hai chuẩn qua token/DPAPI. Đây chưa phải chạy CodeSmith sinh toàn bộ từ schema.

## PasswordHasher tùy chọn — 27/10/2026

Trong profile dùng bộ template này, bật:

```xml
<property name="IncludePasswordHasher">True</property>
```

Mặc định là `False`; hỗ trợ luồng SQL Server và .NET Framework 4.8 hiện tại. Khi bật, generator lấy `SecuritySource/PasswordHasher.cs.txt`, thay namespace DAL rồi sinh `Data/Security/PasswordHasher.cs` và thêm Compile Include vào project Data. Sinh lại sẽ cập nhật file hasher do generator quản lý; tắt tùy chọn không xóa file đã có nhưng project sinh mới không include hasher. Không tắt khi ứng dụng vẫn tham chiếu lớp này.

Hasher dùng PBKDF2-HMAC-SHA256 với 600.000 vòng, salt ngẫu nhiên 16 byte, output 32 byte, định dạng `pbkdf2-sha256$v1$...`. Windows CNG được dùng để thực hiện thuật toán chuẩn. Có kiểm tra định dạng, giới hạn vòng lặp và xác thực hai dạng MD5 legacy của HocPhi/UIS; không tự biết khách hàng nào dùng UIS và không tự đổi dữ liệu.

Mặc định không sinh policy hoặc provider riêng của HocPhi. Các phần này nằm trong file `*.user.cs`; project template include wildcard `**\*.user.*` để đăng ký compile sau khi regenerate. Trường mật khẩu 255 ký tự vẫn lấy từ schema/procedure; tính năng này không tự ALTER database.

Profile HocPhi phải trỏ tới `NetTiers.cst` của bộ template này và bật `IncludePasswordHasher=True` khi generate; chưa sửa profile sản xuất. Luôn kiểm tra `ExecuteSql=False` và dùng output thử để xem diff trước khi đưa vào source thật.

Kiểm thử: `Tests/Test-PasswordHasher.ps1` compile master bằng CodeSmith 7.1 thật, thử bật/tắt và sinh lại asset với hai namespace, render/re-render 24 tổ hợp project (4 vai trò × 3 framework đầu vào × 2 trạng thái), rồi compile/chạy 29 kiểm tra hash cho mỗi namespace trên AnyCPU và x86. Kiểm tra vector độc lập và tương thích Rfc2898DeriveBytes; không truy cập schema, chạy SQL hoặc regenerate project sản xuất. Chạy `Tests/Test-ApiHardening.ps1` để kiểm tra hồi quy các asset kết nối.

### Tự nhúng tích hợp HocPhi trên máy khác

Nếu ứng dụng có `HocPhi/Common/PasswordSecurity.cs`, bật thêm tùy chọn sau trong profile **đang sử dụng bộ template này**:

```xml
<property name="IncludeHocPhiPasswordIntegration">True</property>
```

Tùy chọn này tự bật `IncludePasswordHasher` và sinh đủ ba file:

- `Accounts.Data/Security/PasswordHasher.cs`;
- `Accounts.Data/Security/PasswordStoragePolicy.user.cs`;
- `Accounts.Data.SqlClient/SqlTaiKhoanProvider.PasswordSecurity.user.cs` chứa `GetPasswordStoragePolicy`, `CompareExchangePassword` và accessor của partial base.

Hai asset tích hợp được đóng gói trong `SecuritySource/HocPhi`, không lấy từ workspace HocPhi trên máy chạy generator. Vì vậy output mới trên máy khác cũng có đủ các lớp/phương thức, không cần chép tay. Project Data/SqlClient tự compile các file `.user.cs` qua wildcard sẵn có. Chỉ hỗ trợ namespace DAL `Accounts.Data` và selection sinh provider `TaiKhoanProvider`; phải chọn bảng TaiKhoan cùng các bảng cần generate. Các dự án khác để tùy chọn này `False`.

Generate lại giữ file custom giống asset. Nếu file đích đã có chỉnh sửa khác asset, generator dừng với đường dẫn cần merge, không ghi đè chỉnh sửa. Nếu file `SqlTaiKhoanProvider.cs` cũ còn các phương thức mật khẩu viết trực tiếp, cần chuyển/merge sang file partial để tránh định nghĩa trùng; không tự xóa mã custom cũ.

Lỗi CS0246 `PasswordStoragePolicy` và CS1061 hai phương thức provider sau regenerate trên máy khác được xử lý bằng việc cập nhật **toàn bộ** các file template/asset nói trên, bật tùy chọn rồi generate lại. Nếu vẫn lỗi, kiểm tra profile trỏ đúng `NetTiers.cst` đã cập nhật và reload project trong Visual Studio trước Rebuild Solution. Không cần đổi dòng gọi trong `PasswordSecurity.cs`.

Kiểm thử bổ sung bằng engine thật: output tích hợp mới, generate lặp lại, mặc định tắt, tự bật hasher, từ chối namespace sai và bảo toàn custom khác asset. MSBuild kiểm tra hai project sinh ra thực sự có đúng một Compile item cho từng file tích hợp, không chỉ kiểm tra file có tồn tại trên đĩa. Các test này không kết nối SQL hoặc sửa profile sản xuất.

### Tương thích Encrypt=False — 27/10/2026

- SqlConfiguration.CreateManualSession tạo kết nối mới mặc định Encrypt=True, TrustServerCertificate=False. Overload mới nhận bool encrypt để UI cho phép chọn False. Overload cũ giữ nguyên tùy chọn của phiên cũ, hoặc dùng mặc định an toàn nếu tạo mới.
- Không ép TLS trong SqlSession hoặc decoder: cấu hình đã lưu và token giữ nguyên cờ khi đọc/import. Với overload mới, chọn True luôn xác minh chứng thư; chọn False không tự yêu cầu mã hóa toàn phiên. Không fallback khi TLS lỗi.
- SaveSession khôi phục DPAPI trước đó nếu cập nhật cấu hình thất bại. Token/cipher không bị đổi dạng để thay cờ TLS. Không log dữ liệu cấu hình rõ.
- Asset provider HocPhi bỏ điều kiện TLS trong GetPasswordStoragePolicy: PBKDF2 hoạt động với cả Encrypt=True và False. Đây là hai lớp bảo vệ độc lập; vẫn khuyến nghị TLS khi môi trường đáp ứng.
- Generator nhận dạng chính xác provider từ bản asset cũ trong SecuritySource/HocPhi/Previous, sao lưu rồi tự cập nhật sang bản không chặn Encrypt=False. Tên backup không chứa `.user.` để không bị Compile wildcard đưa vào build. Chỉnh sửa riêng không khớp bản cũ vẫn được bảo toàn và yêu cầu merge.
- HocPhi frmConfig cần bản UI có checkbox Encrypt cùng DLL mới. Template chỉ cập nhật DAL; không sinh lại màn hình cấu hình riêng của ứng dụng.
- Tests/Test-ApiHardening.ps1 hiện có 138 kiểm tra cho mỗi namespace, bao gồm mặc định, giữ cấu hình cũ, token hai định dạng/các trạng thái TLS, DPAPI round-trip và rollback khi lưu lỗi. Tests/Test-PasswordHasher.ps1 kiểm tra thêm nâng cấp provider cũ cùng đăng ký project bằng engine/MSBuild thật. Không cài chứng thư hoặc sửa server tự động.

### Tự thử TLS rồi cập nhật DPAPI — 27/10/2026

SecuritySource/SqlEncryptionUpgrade.cs.txt được sinh vào DAL và đăng ký Compile. SqlConfiguration là static partial; phải cập nhật cả SqlConfiguration.cs và SqlEncryptionUpgrade.cs cùng lúc. App.config template sinh appSettings AutoUpgradeSqlEncryption=true; thiếu key cũng mặc định bật. Đặt false và khởi động lại để giữ cấu hình False lâu dài.

API `TryUpgradeDpapiEncryption(currentReference, reloadProvider)` thử tối đa một lần cho mỗi phiên bản DPAPI trong mỗi tiến trình. Chỉ gọi ở bootstrap/đăng nhập đang nhàn rỗi; callback chỉ reload metadata, không mở kết nối SQL, và phải nhận lại reference cũ khi rollback. Caller phải bind provider với reference hiện hành trước khi gọi và dùng reference trả về. Không đưa API này vào constructor SqlSession hoặc từng câu SQL.

DPAPI thiếu Encrypt hoặc đang False được thử TCP + Encrypt=True + TrustServerCertificate=False; probe cần DMV encrypt_option=TRUE và net_transport=TCP. Probe timeout kết nối/query 3 giây, không giữ SessionGate/file mutex lúc chờ mạng. Probe lỗi không thay file/phiên cũ, không hiện modal và không downgrade cấu hình True.

Commit dùng named mutex Global theo đường dẫn cùng fingerprint kiểm tra lại; các writer cấu hình trong SqlConfiguration tham gia cùng mutex. Lưu atomic, verify DPAPI và reload metadata thành công trước khi publish reference. Backup giữ tới khi callback thành công; lỗi khôi phục file/provider cũ, lỗi recovery phải dừng. Không bỏ phụ thuộc khóa HPCF2 hoặc đổi kind/chuẩn cipher. Phiên chính giữ timeout cũ và dùng TCP đã kiểm tra.

HocPhi/Common/SqlProviderConfiguration.cs tích hợp API vào frmMain và frmDangNhap, cập nhật cả default provider, ConnectionScope của UI và Utility.connection. Các ứng dụng khác dùng template phải tích hợp callback riêng; chỉ regenerate DAL không tự chèn bootstrap vào UI riêng của ứng dụng. Token/App.config không bị viết lại bởi API; nguồn chưa là DPAPI phải qua migration hiện có trước.

Tests/Test-ApiHardening.ps1 hiện đạt 178 kiểm tra cho mỗi namespace, bao gồm fake-probe thành công/thất bại, chống lặp, rollback provider/file, writer đồng thời, mutex giữa hai tiến trình và cipher/key HPCF2 sau upgrade. Tests/Framework48Probe.cst và PasswordHasherProbe.cst kiểm tra mặc định appSetting và Compile Include mới bằng engine. Các unit test không mở SQL; TLS thật với chứng thư tin cậy còn là bước nghiệm thu môi trường.
