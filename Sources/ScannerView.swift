import SwiftUI
import AVFoundation
import PhotosUI
import Vision
import UIKit

// MARK: - Camera

final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var onCode: ((String) -> Void)?
    var onClose: (() -> Void)?

    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?
    private var handled = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            showMessage("无法访问摄像头")
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.qr]
        }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        preview = layer

        addOverlays()

        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func addOverlays() {
        // close button
        let btn = UIButton(type: .system)
        btn.setTitle("关闭", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        btn.backgroundColor = UIColor(white: 1, alpha: 0.18)
        btn.layer.cornerRadius = 10
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(close), for: .touchUpInside)
        view.addSubview(btn)
        NSLayoutConstraint.activate([
            btn.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            btn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            btn.widthAnchor.constraint(equalToConstant: 72),
            btn.heightAnchor.constraint(equalToConstant: 38)
        ])

        // framing hint
        let box = UIView()
        box.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
        box.layer.borderWidth = 2
        box.layer.cornerRadius = 16
        box.translatesAutoresizingMaskIntoConstraints = false
        box.isUserInteractionEnabled = false
        view.addSubview(box)
        NSLayoutConstraint.activate([
            box.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            box.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            box.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.66),
            box.heightAnchor.constraint(equalTo: box.widthAnchor)
        ])

        let hint = UILabel()
        hint.text = "把二维码放进框里"
        hint.textColor = .white
        hint.font = .systemFont(ofSize: 14)
        hint.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hint)
        NSLayoutConstraint.activate([
            hint.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hint.bottomAnchor.constraint(equalTo: box.topAnchor, constant: -14)
        ])
    }

    private func showMessage(_ text: String) {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40)
        ])
    }

    @objc private func close() {
        onClose?()
    }

    // MARK: AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !handled else { return }
        for obj in metadataObjects {
            guard let code = obj as? AVMetadataMachineReadableCodeObject,
                  code.type == .qr,
                  let value = code.stringValue, !value.isEmpty else { continue }
            handled = true
            if session.isRunning { session.stopRunning() }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onCode?(value)
            return
        }
    }
}

struct ScannerView: UIViewControllerRepresentable {
    var onCode: (String) -> Void
    var onClose: () -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        let vc = ScannerController(nibName: nil, bundle: nil)
        vc.onCode = onCode
        vc.onClose = onClose
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}
}

// MARK: - Photo library

struct PhotoScannerView: UIViewControllerRepresentable {
    /// nil means "no QR found in the picked image"
    var onResult: (String?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let vc = PHPickerViewController(configuration: config)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onResult: (String?) -> Void
        init(onResult: @escaping (String?) -> Void) { self.onResult = onResult }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                onResult(nil)
                return
            }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else {
                    DispatchQueue.main.async { self.onResult(nil) }
                    return
                }
                let text = QRImageDecoder.decode(image)
                DispatchQueue.main.async { self.onResult(text) }
            }
        }
    }
}

// MARK: - Image decoding (Vision, with upscale / rotate / contrast retries)

enum QRImageDecoder {

    static func decode(_ image: UIImage) -> String? {
        for variant in variants(of: image) {
            if let s = detect(variant) { return s }
        }
        return nil
    }

    private static func detect(_ image: UIImage) -> String? {
        guard let cg = image.cgImage else { return nil }
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
        do { try handler.perform([request]) } catch { return nil }
        for result in request.results ?? [] {
            if let value = result.payloadStringValue, !value.isEmpty { return value }
        }
        return nil
    }

    /// Blurry photos often decode only after upscaling; rotated ones need rotation.
    private static func variants(of image: UIImage) -> [UIImage] {
        var out: [UIImage] = [image]
        for scale in [2.0, 3.0] {
            if let u = scaled(image, by: scale) { out.append(u) }
        }
        for angle in [90.0, 180.0, 270.0] {
            if let r = rotated(image, degrees: angle) { out.append(r) }
        }
        for angle in [90.0, 270.0] {
            if let u = scaled(image, by: 2.0), let r = rotated(u, degrees: angle) { out.append(r) }
        }
        return out
    }

    private static func scaled(_ image: UIImage, by factor: CGFloat) -> UIImage? {
        let size = CGSize(width: image.size.width * factor, height: image.size.height * factor)
        guard size.width > 0, size.height > 0, size.width < 6000, size.height < 6000 else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func rotated(_ image: UIImage, degrees: CGFloat) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let radians = degrees * .pi / 180
        let newSize: CGSize
        if Int(degrees) % 180 == 0 {
            newSize = image.size
        } else {
            newSize = CGSize(width: image.size.height, height: image.size.width)
        }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { ctx in
            let context = ctx.cgContext
            context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            context.rotate(by: radians)
            context.draw(cg, in: CGRect(x: -image.size.width / 2,
                                        y: -image.size.height / 2,
                                        width: image.size.width,
                                        height: image.size.height))
        }
    }
}
