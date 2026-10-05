#include "sapi_tts.h"

#include <windows.h>
#include <initguid.h>
#include <sapi.h>

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <vector>

namespace {

std::wstring Utf8ToWide(const std::string& s) {
  if (s.empty()) return L"";
  int n = MultiByteToWideChar(CP_UTF8, 0, s.c_str(), -1, nullptr, 0);
  std::wstring w(n, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, s.c_str(), -1, &w[0], n);
  w.resize(n - 1);
  return w;
}

std::string WideToUtf8(const wchar_t* w) {
  if (!w) return "";
  int n = WideCharToMultiByte(CP_UTF8, 0, w, -1, nullptr, 0, nullptr, nullptr);
  std::string s(n, '\0');
  WideCharToMultiByte(CP_UTF8, 0, w, -1, &s[0], n, nullptr, nullptr);
  s.resize(n - 1);
  return s;
}

class SapiTts {
 public:
  SapiTts() {
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    CoCreateInstance(CLSID_SpVoice, nullptr, CLSCTX_ALL, IID_ISpVoice, (void**)&voice_);
  }
  ~SapiTts() {
    if (voice_) voice_->Release();
  }

  bool ok() const { return voice_ != nullptr; }

  bool Speak(const std::string& text) {
    if (!voice_) return false;
    std::wstring w = Utf8ToWide(text);
    HRESULT hr = voice_->Speak(w.c_str(), SPF_ASYNC | SPF_PURGEBEFORESPEAK | SPF_IS_NOT_XML, nullptr);
    return SUCCEEDED(hr);
  }

  void Stop() {
    if (voice_) voice_->Speak(nullptr, SPF_PURGEBEFORESPEAK, nullptr);
  }

  bool IsSpeaking() {
    if (!voice_) return false;
    SPVOICESTATUS st{};
    if (FAILED(voice_->GetStatus(&st, nullptr))) return false;
    // 0 = queued but not started yet, SPRS_IS_SPEAKING = running, SPRS_DONE = finished.
    return st.dwRunningState != SPRS_DONE;
  }

  void SetRate(long rate) {
    if (voice_) voice_->SetRate(rate);
  }

  // Enumerate installed voices: vector of (id, name).
  std::vector<std::pair<std::string, std::string>> Voices() {
    std::vector<std::pair<std::string, std::string>> out;
    ISpObjectTokenCategory* cat = nullptr;
    if (FAILED(CoCreateInstance(CLSID_SpObjectTokenCategory, nullptr, CLSCTX_ALL, IID_ISpObjectTokenCategory, (void**)&cat))) return out;
    if (SUCCEEDED(cat->SetId(SPCAT_VOICES, FALSE))) {
      IEnumSpObjectTokens* en = nullptr;
      if (SUCCEEDED(cat->EnumTokens(nullptr, nullptr, &en)) && en) {
        ISpObjectToken* tok = nullptr;
        while (en->Next(1, &tok, nullptr) == S_OK && tok) {
          LPWSTR id = nullptr;
          LPWSTR name = nullptr;
          tok->GetId(&id);
          tok->GetStringValue(nullptr, &name);
          out.emplace_back(WideToUtf8(id), WideToUtf8(name));
          if (id) CoTaskMemFree(id);
          if (name) CoTaskMemFree(name);
          tok->Release();
          tok = nullptr;
        }
        en->Release();
      }
    }
    cat->Release();
    return out;
  }

  bool SetVoice(const std::string& id) {
    if (!voice_) return false;
    if (id.empty()) return SUCCEEDED(voice_->SetVoice(nullptr));
    ISpObjectTokenCategory* cat = nullptr;
    if (FAILED(CoCreateInstance(CLSID_SpObjectTokenCategory, nullptr, CLSCTX_ALL, IID_ISpObjectTokenCategory, (void**)&cat))) return false;
    bool done = false;
    if (SUCCEEDED(cat->SetId(SPCAT_VOICES, FALSE))) {
      IEnumSpObjectTokens* en = nullptr;
      if (SUCCEEDED(cat->EnumTokens(nullptr, nullptr, &en)) && en) {
        ISpObjectToken* tok = nullptr;
        while (!done && en->Next(1, &tok, nullptr) == S_OK && tok) {
          LPWSTR tid = nullptr;
          tok->GetId(&tid);
          if (tid && WideToUtf8(tid) == id) done = SUCCEEDED(voice_->SetVoice(tok));
          if (tid) CoTaskMemFree(tid);
          tok->Release();
          tok = nullptr;
        }
        en->Release();
      }
    }
    cat->Release();
    return done;
  }

 private:
  ISpVoice* voice_ = nullptr;
};

std::unique_ptr<SapiTts> g_tts;
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_channel;

}  // namespace

void RegisterSapiTts(flutter::FlutterEngine* engine) {
  g_tts = std::make_unique<SapiTts>();
  g_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine->messenger(), "grammar/tts", &flutter::StandardMethodCodec::GetInstance());
  g_channel->SetMethodCallHandler([](const flutter::MethodCall<flutter::EncodableValue>& call,
                                     std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const std::string& m = call.method_name();
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    auto str_arg = [&](const char* key) -> std::string {
      if (!args) return "";
      auto it = args->find(flutter::EncodableValue(key));
      if (it == args->end()) return "";
      if (const auto* s = std::get_if<std::string>(&it->second)) return *s;
      return "";
    };
    auto int_arg = [&](const char* key, int def) -> int {
      if (!args) return def;
      auto it = args->find(flutter::EncodableValue(key));
      if (it == args->end()) return def;
      if (const auto* i = std::get_if<int32_t>(&it->second)) return *i;
      if (const auto* l = std::get_if<int64_t>(&it->second)) return (int)*l;
      return def;
    };
    if (!g_tts || !g_tts->ok()) {
      result->Error("sapi", "SAPI voice not available");
      return;
    }
    if (m == "speak") {
      result->Success(flutter::EncodableValue(g_tts->Speak(str_arg("text"))));
    } else if (m == "stop") {
      g_tts->Stop();
      result->Success();
    } else if (m == "isSpeaking") {
      result->Success(flutter::EncodableValue(g_tts->IsSpeaking()));
    } else if (m == "setRate") {
      g_tts->SetRate(int_arg("rate", 0));
      result->Success();
    } else if (m == "getVoices") {
      flutter::EncodableList list;
      for (const auto& v : g_tts->Voices()) {
        flutter::EncodableMap mm;
        mm[flutter::EncodableValue("id")] = flutter::EncodableValue(v.first);
        mm[flutter::EncodableValue("name")] = flutter::EncodableValue(v.second);
        list.push_back(flutter::EncodableValue(mm));
      }
      result->Success(flutter::EncodableValue(list));
    } else if (m == "setVoice") {
      result->Success(flutter::EncodableValue(g_tts->SetVoice(str_arg("id"))));
    } else {
      result->NotImplemented();
    }
  });
}
