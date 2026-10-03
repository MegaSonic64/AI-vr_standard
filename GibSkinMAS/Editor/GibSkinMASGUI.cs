#if UNITY_EDITOR
using UnityEditor;

public sealed class GibSkinMASGUI : ShaderGUI
{
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        materialEditor.PropertiesDefaultGUI(properties);
        materialEditor.RenderQueueField();

        MaterialProperty horizon = FindProperty("_SpecularHorizonOcclusion", properties, false);
        if (horizon != null)
        {
            EditorGUI.showMixedValue = horizon.hasMixedValue;
            EditorGUI.BeginChangeCheck();
            bool horizonEnabled = EditorGUILayout.Toggle("SLZ Specular Horizon Occlusion", horizon.floatValue > 0.5f);
            if (EditorGUI.EndChangeCheck())
                horizon.floatValue = horizonEnabled ? 1.0f : 0.0f;
            EditorGUI.showMixedValue = false;
        }

        materialEditor.EnableInstancingField();
        materialEditor.DoubleSidedGIField();
    }
}
#endif
