//-----------------------------------------------------------------------------
// File: Scene.h
//-----------------------------------------------------------------------------

#pragma once

#include "Shader.h"
#include "Player.h"

struct LIGHT
{
	XMFLOAT4				m_xmf4Ambient;
	XMFLOAT4				m_xmf4Diffuse;
	XMFLOAT4				m_xmf4Specular;
	XMFLOAT3				m_xmf3Position;
	float 					m_fFalloff;
	XMFLOAT3				m_xmf3Direction;
	float 					m_fTheta; //cos(m_fTheta)
	XMFLOAT3				m_xmf3Attenuation;
	float					m_fPhi; //cos(m_fPhi)
	bool					m_bEnable;
	int						m_nType;
	float					m_fRange;
	float					padding;
};

struct LIGHTS
{
	LIGHT					m_pLights[MAX_LIGHTS];
	XMFLOAT4				m_xmf4GlobalAmbient;
};

struct MATERIAL
{
	XMFLOAT4				m_xmf4Ambient;
	XMFLOAT4				m_xmf4Diffuse;
	XMFLOAT4				m_xmf4Specular; //(r,g,b,a=power)
	XMFLOAT4				m_xmf4Emissive;
};

struct MATERIALS
{
	MATERIAL				m_pReflections[MAX_MATERIALS];
};

class CDescriptorHeap
{
public:
	CDescriptorHeap();
	~CDescriptorHeap();

	ID3D12DescriptorHeap* m_pd3dCbvSrvDescriptorHeap = NULL;

	D3D12_CPU_DESCRIPTOR_HANDLE			m_d3dCbvCPUDescriptorStartHandle;
	D3D12_GPU_DESCRIPTOR_HANDLE			m_d3dCbvGPUDescriptorStartHandle;
	D3D12_CPU_DESCRIPTOR_HANDLE			m_d3dSrvCPUDescriptorStartHandle;
	D3D12_GPU_DESCRIPTOR_HANDLE			m_d3dSrvGPUDescriptorStartHandle;

	D3D12_CPU_DESCRIPTOR_HANDLE			m_d3dCbvCPUDescriptorNextHandle;
	D3D12_GPU_DESCRIPTOR_HANDLE			m_d3dCbvGPUDescriptorNextHandle;
	D3D12_CPU_DESCRIPTOR_HANDLE			m_d3dSrvCPUDescriptorNextHandle;
	D3D12_GPU_DESCRIPTOR_HANDLE			m_d3dSrvGPUDescriptorNextHandle;

	D3D12_CPU_DESCRIPTOR_HANDLE GetCPUDescriptorHandleForHeapStart() { return(m_pd3dCbvSrvDescriptorHeap->GetCPUDescriptorHandleForHeapStart()); }
	D3D12_GPU_DESCRIPTOR_HANDLE GetGPUDescriptorHandleForHeapStart() { return(m_pd3dCbvSrvDescriptorHeap->GetGPUDescriptorHandleForHeapStart()); }

	D3D12_CPU_DESCRIPTOR_HANDLE GetCPUCbvDescriptorStartHandle() { return(m_d3dCbvCPUDescriptorStartHandle); }
	D3D12_GPU_DESCRIPTOR_HANDLE GetGPUCbvDescriptorStartHandle() { return(m_d3dCbvGPUDescriptorStartHandle); }
	D3D12_CPU_DESCRIPTOR_HANDLE GetCPUSrvDescriptorStartHandle() { return(m_d3dSrvCPUDescriptorStartHandle); }
	D3D12_GPU_DESCRIPTOR_HANDLE GetGPUSrvDescriptorStartHandle() { return(m_d3dSrvGPUDescriptorStartHandle); }
};

class CScene
{
public:
    CScene();
    ~CScene();

	bool OnProcessingMouseMessage(HWND hWnd, UINT nMessageID, WPARAM wParam, LPARAM lParam);
	bool OnProcessingKeyboardMessage(HWND hWnd, UINT nMessageID, WPARAM wParam, LPARAM lParam);

	void BuildObjects(ID3D12Device *pd3dDevice, ID3D12GraphicsCommandList *pd3dCommandList);
	void ReleaseObjects();

	void BuildLightsAndMaterials();

	ID3D12RootSignature *CreateGraphicsRootSignature(ID3D12Device *pd3dDevice);
	ID3D12RootSignature *GetGraphicsRootSignature() { return(m_pd3dGraphicsRootSignature); }
	void SetGraphicsRootSignature(ID3D12GraphicsCommandList *pd3dCommandList) { pd3dCommandList->SetGraphicsRootSignature(m_pd3dGraphicsRootSignature); }

	virtual void CreateShaderVariables(ID3D12Device *pd3dDevice, ID3D12GraphicsCommandList *pd3dCommandList);
	virtual void UpdateShaderVariables(ID3D12GraphicsCommandList *pd3dCommandList);
	virtual void ReleaseShaderVariables();

	bool ProcessInput(UCHAR *pKeysBuffer);
    void AnimateObjects(float fTimeElapsed);

	void OnPrepareRender(ID3D12GraphicsCommandList* pd3dCommandList, CCamera* pCamera);
    void Render(ID3D12GraphicsCommandList *pd3dCommandList, CCamera *pCamera=NULL);

	void ReleaseUploadBuffers();

	CPlayer						*m_pPlayer = NULL;

protected:
	ID3D12RootSignature			*m_pd3dGraphicsRootSignature = NULL;

	CShader						**m_ppShaders = NULL;
	int							m_nShaders = 0;

	LIGHTS						*m_pLights = NULL;

	ID3D12Resource				*m_pd3dcbLights = NULL;
	LIGHTS						*m_pcbMappedLights = NULL;

	MATERIALS					*m_pMaterials = NULL;

	ID3D12Resource				*m_pd3dcbMaterials = NULL;
	MATERIAL					*m_pcbMappedMaterials = NULL;

public:
	static CDescriptorHeap*		m_pDescriptorHeap;

	static void CreateCbvSrvDescriptorHeaps(ID3D12Device* pd3dDevice, int nConstantBufferViews, int nShaderResourceViews);
	static void CreateConstantBufferViews(ID3D12Device* pd3dDevice, int nConstantBufferViews, ID3D12Resource* pd3dConstantBuffers, UINT nStride);
	static D3D12_GPU_DESCRIPTOR_HANDLE CreateConstantBufferView(ID3D12Device* pd3dDevice, ID3D12Resource* pd3dConstantBuffer, UINT nStride);
	static D3D12_GPU_DESCRIPTOR_HANDLE CreateConstantBufferView(ID3D12Device* pd3dDevice, D3D12_GPU_VIRTUAL_ADDRESS d3dGpuVirtualAddress, UINT nStride);
	static void CreateShaderResourceViews(ID3D12Device* pd3dDevice, CTexture* pTexture, UINT nDescriptorHeapIndex, UINT nRootParameterStartIndex);
	static void CreateShaderResourceViews(ID3D12Device* pd3dDevice, int nResources, ID3D12Resource** ppd3dResources, DXGI_FORMAT* pdxgiSrvFormats);
	static D3D12_GPU_DESCRIPTOR_HANDLE CScene::CreateShaderResourceView(ID3D12Device* pd3dDevice, ID3D12Resource* pd3dResource, DXGI_FORMAT dxgiSrvFormat);
	static void CreateShaderResourceView(ID3D12Device* pd3dDevice, CTexture* pTexture, int nIndex, UINT nRootParameterStartIndex);
	static void CreateShaderResourceView(ID3D12Device* pd3dDevice, CTexture* pTexture, int nIndex);

	static D3D12_CPU_DESCRIPTOR_HANDLE GetCPUDescriptorHandleForHeapStart() { return(m_pDescriptorHeap->m_pd3dCbvSrvDescriptorHeap->GetCPUDescriptorHandleForHeapStart()); }
	static D3D12_GPU_DESCRIPTOR_HANDLE GetGPUDescriptorHandleForHeapStart() { return(m_pDescriptorHeap->m_pd3dCbvSrvDescriptorHeap->GetGPUDescriptorHandleForHeapStart()); }

	static D3D12_CPU_DESCRIPTOR_HANDLE GetCPUCbvDescriptorStartHandle() { return(m_pDescriptorHeap->m_d3dCbvCPUDescriptorStartHandle); }
	static D3D12_GPU_DESCRIPTOR_HANDLE GetGPUCbvDescriptorStartHandle() { return(m_pDescriptorHeap->m_d3dCbvGPUDescriptorStartHandle); }
	static D3D12_GPU_DESCRIPTOR_HANDLE GetGPUCbvDescriptorNextHandle() { return(m_pDescriptorHeap->m_d3dCbvGPUDescriptorNextHandle); }
	static D3D12_CPU_DESCRIPTOR_HANDLE GetCPUSrvDescriptorStartHandle() { return(m_pDescriptorHeap->m_d3dSrvCPUDescriptorStartHandle); }
	static D3D12_GPU_DESCRIPTOR_HANDLE GetGPUSrvDescriptorStartHandle() { return(m_pDescriptorHeap->m_d3dSrvGPUDescriptorStartHandle); }
};
